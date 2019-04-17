/*

  MacOS X implementation of the SKK input method.

  Copyright (C) 2010 Tomotaka SUWA <tomotaka.suwa@gmail.com>

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

#include "SKKHttpDictionaryLoader.h"
#include <fstream>
#include <sys/stat.h>

void SKKHttpDictionaryLoader::Initialize(const std::string& location) {
    std::istringstream buf(location);
    std::string addr;
    std::string url;
    std::string tmp_path;

    buf >> addr >> url;

    buf.ignore(1);
    std::getline(buf, path_);
    
    tmp_path = path_ + ".download";
    
    initialize_client();
    
    client_->Initialize(addr, url, path_, tmp_path);
}

bool SKKHttpDictionaryLoader::NeedsUpdate() {
    //net::socket::tcpstream http(remote_);

    if(client_->request()) {
        return client_->download(client_->content_length());
    }

    return false;
}

const std::string& SKKHttpDictionaryLoader::FilePath() const {
    return path_;
}

void SKKHttpDictionaryLoader::initialize_client() {
    client_ = new SKKDictionaryHttpClient();
}
