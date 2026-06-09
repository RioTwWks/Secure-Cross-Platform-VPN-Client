#include "include/v2ray_box/v2ray_box_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "v2ray_box_plugin.h"

void V2rayBoxPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  v2ray_box::V2rayBoxPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
