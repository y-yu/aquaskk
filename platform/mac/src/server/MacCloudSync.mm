/* -*- ObjC -*-

 MacOS X implementation of the SKK input method.

 Copyright (C) 2008 Tomotaka SUWA <t.suwa@mac.com>

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

 */

#import <Foundation/Foundation.h>
#include <algorithm>
#include <iterator>
#include <map>
#import "MacCloudSync.h"
#include "SKKCandidateSuite.h"

namespace {
    template<typename T>
    void each_slice(T& x, int slice, void (^f)(typename T::iterator from, typename T::iterator to) ) {
        int size = x.size();
        for(int i = 0; i < size / 50 + 1; i++) {
            typename T::iterator from = x.begin() + i * 50;
            typename T::iterator to = x.begin() + MIN((i + 1)* 50, size);
            f(from, to);
        }
    }

    template<typename Key, typename Value>
    Value at(const std::map<Key, Value>& data, const Key& key)
    {
        typename std::map<Key, Value>::const_iterator it = data.find(key);
        if(it != data.end()) return it->second;
        else return Value();
    }
}

MacCloudSync::~MacCloudSync() {
    loader_->Stop();
}

void MacCloudSync::Initialize(SKKDictionaryFile& dictionaryFile) {
    database_ = [[CKContainer defaultContainer] privateCloudDatabase];
    dictionaryFile_ = &dictionaryFile;

    loader_ = new MacCloudLoader(database_, dictionaryFile_);
    timer_ = std::auto_ptr<pthread::timer>(new pthread::timer(loader_, 60));
}

void MacCloudSync::Save() {
    NSLog(@"Save");
    save(true, dictionaryFile_->OkuriAri());
    save(false, dictionaryFile_->OkuriNasi());
}

void MacCloudSync::fetch(CKQuery* query, void (^f)(const std::map<std::string, CKRecord*>& records)) {
    [database_ performQuery:query inZoneWithID:nil completionHandler:^(NSArray *results, NSError *error) {
        if(error) {
            NSLog(@"[sync] fetch error: %@", error);
        } else {
            std::map<std::string, CKRecord*> map;
            for(CKRecord *record in results) {
                std::string key([[record.recordID recordName] UTF8String]);
                map[key] = record;
            }
            f(map);
        }
    }];
}

CKQuery* MacCloudSync::buildQuery(bool okuri, SKKDictionaryEntryIterator from, SKKDictionaryEntryIterator to) {
    NSMutableArray *xs = [[NSMutableArray alloc] init];
    for(SKKDictionaryEntryIterator it = from; it != to; ++it) {
        NSString* entry = [NSString stringWithUTF8String: it->first.c_str()];
        CKRecordID* recordID = [[CKRecordID alloc] initWithRecordName:entry];
        CKReference* reference = [[CKReference alloc] initWithRecordID:recordID action:CKReferenceActionNone];

        [xs addObject: reference];

        [reference release];
        [recordID release];
    }

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"okuri == %@ AND recordID in %@", okuri ? @1 : @0, xs, nil];
    CKQuery* query = [[CKQuery alloc] initWithRecordType:@"DictionaryEntry" predicate:predicate];
    [xs release];
    return query;
}

void MacCloudSync::create(NSString* entry, NSString* candidates, bool okuri) {
    if(!entry) { return; }
    NSLog(@"[sync] create: %@ %@", entry, candidates);
    CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName:entry];
    CKRecord* newRecord = [[CKRecord alloc] initWithRecordType:@"DictionaryEntry" recordID:recordID];
    newRecord[@"candidates"] = candidates;
    newRecord[@"okuri"] = okuri ? @1 : @0;
    newRecord[@"updatedAt"] = [NSDate date];
    [database_ saveRecord:newRecord completionHandler:^(CKRecord *record, NSError *error) {
        if(error) {
            NSLog(@"[sync]Create new record error: %@", error);
        }
    }];
    [newRecord release];
    [recordID release];
}

void MacCloudSync::update(CKRecord* record, NSString* candidates, bool okuri) {
    NSLog(@"[sync] update: %@ %@", record.recordID.recordName, candidates);
    record[@"candidates"] = candidates;
    record[@"okuri"] = okuri ? @1 : @0;
    record[@"updatedAt"] = [NSDate date];
    [database_ saveRecord:record completionHandler:^(CKRecord *record, NSError *error) {
        if(error) {
            NSLog(@"[sync]Create new record error: %@", error);
        }
    }];
}

void MacCloudSync::notify(int created, int updated) {
    if(created == 0 && updated == 0) { return; }
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"AquaSKK同期";
    notification.subtitle = [NSString stringWithFormat: @"%d件を作成 / %d件を更新", created, updated];
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    [notification release];
}

void MacCloudSync::save(bool okuri, SKKDictionaryEntryContainer& container) {
    // 全数の取得はできないので、50件づつで処理する
    each_slice(container, 50, ^(SKKDictionaryEntryIterator from, SKKDictionaryEntryIterator to) {
        // containerが変更されるとiteratorが無効になるので、ここでコピーしておく
        SKKDictionaryEntryContainer tmp;
        std::copy(from, to, std::back_inserter(tmp));

        CKQuery *query = buildQuery(okuri, from, to);
        fetch(query, ^(const std::map<std::string, CKRecord*>& records) {
            int created = 0, updated = 0;

            for(SKKDictionaryEntryContainer::const_iterator it = tmp.begin(); it != tmp.end(); ++it) {
                NSString* entry = [NSString stringWithUTF8String: it->first.c_str()];
                NSString* candidates = [NSString stringWithUTF8String: it->second.c_str()];
                if(CKRecord* record = at(records, it->first)) {
                    if(![candidates isEqualToString: record[@"candidates"]]) {
                        updated ++;
                        update(record, candidates, okuri);
                    }
                } else {
                    created ++;
                    create(entry, candidates, okuri);
                }
            }
             // まだ更新は完了してないけど、通知をだしちゃう。
            notify(created, updated);
        });
        [query release];
    });
}
