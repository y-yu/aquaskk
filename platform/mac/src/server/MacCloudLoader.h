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

#ifndef MacCloudLoader_h
#define MacCloudLoader_h

#include "pthreadutil.h"
#import <CloudKit/CloudKit.h>
#include "SKKDictionaryFile.h"

class MacCloudLoader : public pthread::task {
    CKDatabase* database_;
    SKKDictionaryFile* dictionaryFile_;
    NSDate* lastUpdate_;

    void fetchAll(bool okuri, SKKDictionaryEntryContainer& container);
    void fetchAll(CKQueryOperation* operation, SKKDictionaryEntryContainer& container);

public:
    MacCloudLoader(CKDatabase* database, SKKDictionaryFile* dictionaryFile);
    virtual bool run();
};

#endif
