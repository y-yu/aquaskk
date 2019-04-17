#include <cassert>
#include <sys/stat.h>
#include "SKKAutoUpdateDictionary.h"
#include "SKKDictionaryHttpClient.h"

class SKKDictionaryHttpClientTestImpl : public SKKDictionaryHttpClient {
public:
    virtual void Initialize(std::string addr, std::string url, std::string path, std::string tmp_path) { }
  virtual bool request() {
    return true;
  }
  virtual int content_length() {
    return 1;
  }
  virtual int file_size(std::string& path) const {
    return 1;
  }
  virtual bool download(int length) {
    return true;
  }
};

class SKKHttpDictionaryLoaderTestImpl : public SKKHttpDictionaryLoader {
public:
    void initialize_client() {
        client_ = new SKKDictionaryHttpClientTestImpl();
    }
};

typedef SKKDictionaryTemplate<SKKHttpDictionaryLoaderTestImpl> SKKAutoUpdateDictionaryTest;

int main() {
    const char* path1 = "SKK-JISYO.S1";
    const char* path2 = "SKK-JISYO.S2";
    SKKAutoUpdateDictionaryTest dict1, dict2;
    SKKCandidateSuite suite;

    remove(path1);
    remove(path2);

    dict1.Initialize("openlab.ring.gr.jp /skk/skk/dic/SKK-JISYO.S SKK-JISYO.S1");
    dict2.Initialize("openlab.ring.gr.jp:80 /skk/skk/dic/SKK-JISYO.S SKK-JISYO.S2");

    dict1.Find(SKKEntry("dummy", "d"), suite);
    dict2.Find(SKKEntry("dummy", "d"), suite);

    struct stat st1, st2;

    stat(path1, &st1);
    stat(path2, &st2);

    assert(st1.st_size == st2.st_size);

    assert(dict1.ReverseLookup("逆") == "ぎゃく");
    assert(dict2.ReverseLookup("逆") == "ぎゃく");
}
