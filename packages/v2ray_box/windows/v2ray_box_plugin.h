#ifndef FLUTTER_PLUGIN_V2RAY_BOX_PLUGIN_H_
#define FLUTTER_PLUGIN_V2RAY_BOX_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace v2ray_box {

class V2rayBoxPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  V2rayBoxPlugin();

  virtual ~V2rayBoxPlugin();

  // Disallow copy and assign.
  V2rayBoxPlugin(const V2rayBoxPlugin&) = delete;
  V2rayBoxPlugin& operator=(const V2rayBoxPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace v2ray_box

#endif  // FLUTTER_PLUGIN_V2RAY_BOX_PLUGIN_H_
