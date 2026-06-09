#ifndef V2RAY_BOX_SYSTEM_PROXY_H_
#define V2RAY_BOX_SYSTEM_PROXY_H_

#include <string>

namespace v2ray_box {

class SystemProxy {
 public:
  static bool IsSupported();
  static bool Enable(const std::string& host,
                     int port,
                     const std::string& username,
                     const std::string& password);
  static bool Disable();
};

bool ConfigOptionsSetSystemProxy(const std::string& json);

}  // namespace v2ray_box

#endif  // V2RAY_BOX_SYSTEM_PROXY_H_
