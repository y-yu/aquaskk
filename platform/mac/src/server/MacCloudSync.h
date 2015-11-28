/* -*- ObjC -*-

 MacOS X implementation of the SKK input method.

 Copyright (C) 2015 mzp <mzpppp@gmail.com>

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

#ifndef MacCloudSync_h
#define MacCloudSync_h

#include <map>
#include <string>
#import <CloudKit/CloudKit.h>
#include "SKKCloudSync.h"
#include "MacCloudLoader.h"

class MacCloudSync : public SKKCloudSync {
    std::auto_ptr<pthread::timer> timer_;

    SKKDictionaryEntryContainer restoreOkuriAri_;
    SKKDictionaryEntryContainer restoreOkuriNasi_;

    SKKDictionaryEntryContainer deletedOkuriAri_;
    SKKDictionaryEntryContainer deletedOkuriNasi_;

    MacCloudLoader* loader_;
    CKDatabase* database_;
    SKKDictionaryFile* dictionaryFile_;

    void fetch(CKQuery* query, void (^f)(const std::map<std::string, CKRecord*>& records));
    void create(NSString* entry, NSString* candidates, bool okuri);
    void update(CKRecord* record, NSString* candidates, bool okuri);
    void restore(NSString* entry, NSString* candidate, bool okuri);
    void remove(NSString* entry, NSString* candidate, bool okuri);
    void save(bool okuri, SKKDictionaryEntryContainer& container);
    void notify(NSString* text);
    void notifyRemove(int deleted);

    CKQuery* buildQuery(bool okuri, SKKDictionaryEntryIterator from, SKKDictionaryEntryIterator to);

public:
    virtual ~MacCloudSync();
    virtual void Initialize(SKKDictionaryFile& dictionaryFile);
    virtual void Save();
    virtual void Register(const SKKEntry& entry, const std::string& kanji, bool okuri);
    virtual void Remove(const SKKEntry& entry, const std::string& kanji, bool okuri);
};

#endif
