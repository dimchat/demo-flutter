#include "include/dim_flutter/dim_flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "dim_flutter_plugin.h"

void DimFlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  dim_flutter::DimFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
