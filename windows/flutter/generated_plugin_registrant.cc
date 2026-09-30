//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <audioplayers_windows/audioplayers_windows_plugin.h>
#include <camera_windows/camera_windows.h>
#include <flutter_tts/flutter_tts_plugin.h>
#include <url_launcher_windows/url_launcher_windows.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AudioplayersWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AudioplayersWindowsPlugin"));
  CameraWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("CameraWindows"));
  FlutterTtsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterTtsPlugin"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
}
