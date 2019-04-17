/* -*- C++ -*-
 
 MacOS X implementation of the SKK input method.
 
 Copyright (C) 2019 Hikaru YOSHIMURA <yyu@mental.poker>
 
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

#ifndef SKKDictionaryHttpClient_h
#define SKKDictionaryHttpClient_h

#include "socketutil.h"

class SKKDictionaryHttpClient {
    
protected:
    net::socket::endpoint remote_;
    std::string url_;
    std::string path_;
    std::string tmp_path_;

public:    
    virtual void Initialize(std::string addr, std::string url, std::string path, std::string tmp_path);
    virtual bool request();
    virtual int content_length();
    virtual int file_size(std::string& path) const;
    virtual bool download(int length);
};

#endif
