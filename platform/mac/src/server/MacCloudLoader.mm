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

    void update(const std::string& entry, const std::string& candidates, SKKDictionaryEntryContainer& container) {
        SKKCandidateParser parser;
        parser.Parse(candidates);

        // 候補が空のやつは無視する。
        // TOTO: カタカナの学習結果も含まれるけど、どうする?
        if(parser.Candidates().empty()) { return; }

        // 既存の内容とマージする
        // TODO: 削除を扱えるようにする
        SKKCandidateSuite suite;
        SKKDictionaryEntryIterator iter = find(container, entry);
        if(iter != container.end()) {
            suite.Parse(iter->second);
            container.erase(iter);
        }
        suite.Add(parser.Candidates());

        container.push_front(SKKDictionaryEntry(entry, suite.ToString()));
    }
}

MacCloudLoader::MacCloudLoader(CKDatabase* database, SKKDictionaryFile* dictionaryFile)
:database_(database), dictionaryFile_(dictionaryFile)
{
    lastUpdate_ = [[NSDate dateWithTimeIntervalSince1970:0] retain];
}

void MacCloudLoader::fetchAll(bool okuri, SKKDictionaryEntryContainer& container) {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(okuri == %@) AND (updatedAt >= %@)", okuri ? @1 : @0, lastUpdate_, nil];

    CKQuery* query = [[CKQuery alloc] initWithRecordType:@"DictionaryEntry" predicate:predicate];
    CKQueryOperation* operation = [[CKQueryOperation alloc] initWithQuery:query];
    fetchAll(operation, container);
    [query release];
    [operation release];
}

void MacCloudLoader::fetchAll(CKQueryOperation* operation, SKKDictionaryEntryContainer& container) {
    operation.recordFetchedBlock = ^(CKRecord* record) {
        NSLog(@"fetch entry: %@ %@", record.recordID.recordName, record[@"candidates"]);

        std::string entry([record.recordID.recordName UTF8String]);
        std::string candidates([record[@"candidates"] UTF8String]);
        update(entry, candidates, container);
    };

    operation.queryCompletionBlock = ^(CKQueryCursor* cursor, NSError* error) {
        if(error) {
            NSLog(@"fetchAll error: %@", error);
        } else if(cursor) {
            CKQueryOperation* operation = [[CKQueryOperation alloc] initWithCursor:cursor];
            fetchAll(operation, container);
            [operation release];
        } else {
            [lastUpdate_ release];
            lastUpdate_ = [[NSDate date] retain];
        }
    };

    [database_ addOperation:operation];
}

bool MacCloudLoader::run() {
    NSLog(@"fetch update from icloud");
    fetchAll(true, dictionaryFile_->OkuriAri());
    fetchAll(false, dictionaryFile_->OkuriNasi());
    return true;
}