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
#include "MacCloudLoader.h"
#include "SKKCandidateSuite.h"

namespace {
    // SKKDictionaryEntry と文字列を比較するファンクタ
    class CompareUserDictionaryEntry: public std::unary_function<SKKDictionaryEntry, bool> {
        const std::string str_;

    public:
        CompareUserDictionaryEntry(const std::string& str) : str_(str) {}

        bool operator()(const SKKDictionaryEntry& entry) const {
            return entry.first == str_;
        }
    };

    SKKDictionaryEntryIterator find(SKKDictionaryEntryContainer& container, const std::string& query) {
        return std::find_if(container.begin(), container.end(),
                            CompareUserDictionaryEntry(query));
    }

    SKKDictionaryEntry make(const std::string& entry, const std::string& candidates) {
        // 候補が空の場合は、'//'が入力されていたものとして扱う。
        // データがおかしくなっても、ここで自動的に元にもどるようにする。
        if(candidates.empty()) {
            return SKKDictionaryEntry(entry, "//");
        } else {
            return SKKDictionaryEntry(entry, candidates);
        }
    }

    bool update(const std::string& entry, const std::string& candidates, SKKDictionaryEntryContainer& container) {
        SKKDictionaryEntryIterator iter = find(container, entry);

        if(iter != container.end()) {
            // 更新
            if(iter->second == candidates && !candidates.empty()) {
                // 同様の内容なので更新不要
                return false;
            } else {
                // マージする
                SKKCandidateSuite suite;

                // iCloudから取得した分
                SKKCandidateParser parser;
                parser.Parse(candidates);
                suite.Add(parser.Candidates());

                // もともとあった分
                parser.Parse(iter->second);
                suite.Add(parser.Candidates());

                container.erase(iter);

                container.push_front(make(entry, suite.ToString()));
                return true;
            }
        } else {
            // 新規追加
            container.push_front(make(entry, candidates));
            return true;
        }
    }
}

MacCloudLoader::MacCloudLoader(CKDatabase* database, SKKDictionaryFile* dictionaryFile)
:database_(database), dictionaryFile_(dictionaryFile), fetchedCount_(0)
{
    lastUpdate_ = [[NSDate dateWithTimeIntervalSince1970:0] retain];
}

void MacCloudLoader::fetchAll() {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"updatedAt >= %@", lastUpdate_, nil];
    CKQuery* query = [[CKQuery alloc] initWithRecordType:@"DictionaryEntry" predicate:predicate];

    CKQueryOperation* operation = [[CKQueryOperation alloc] initWithQuery:query];
    fetchAll(operation);

    [query release];
    [operation release];
}

void MacCloudLoader::fetchAll(CKQueryOperation* operation) {
    operation.recordFetchedBlock = ^(CKRecord* record) {
        NSLog(@"fetch entry: %@ %@", record.recordID.recordName, record[@"candidates"]);

        std::string entry([record.recordID.recordName UTF8String]);
        std::string candidates([record[@"candidates"] UTF8String]);

        SKKDictionaryEntryContainer& container = [record[@"okuri"] intValue] == 1 ?
            dictionaryFile_->OkuriAri() : dictionaryFile_->OkuriNasi();
        bool ret = update(entry, candidates, container);
        fetchedCount_ += ret ? 1 : 0;
    };

    operation.queryCompletionBlock = ^(CKQueryCursor* cursor, NSError* error) {
        if(error) {
            NSLog(@"fetchAll error: %@", error);
        } else if(cursor) {
            CKQueryOperation* operation = [[CKQueryOperation alloc] initWithCursor:cursor];
            fetchAll(operation);
            [operation release];
        } else {
            [lastUpdate_ release];
            NSLog(@"fetch end");

            if(fetchedCount_ != 0) {
                NSUserNotification *notification = [[NSUserNotification alloc] init];
                notification.title = @"AquaSKK同期";
                notification.subtitle = [NSString stringWithFormat: @"%d件を取得", fetchedCount_];
                [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
                [notification release];
            }

            fetchedCount_ = 0;
            lastUpdate_ = [[NSDate date] retain];
        }
    };

    [database_ addOperation:operation];
}

bool MacCloudLoader::run() {
    NSLog(@"fetch update from icloud");
    fetchAll();
    return true;
}