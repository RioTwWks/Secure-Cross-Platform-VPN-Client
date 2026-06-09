#include "system_proxy.h"

#include "desktop_core.h"

#include <gio/gio.h>

#include <fstream>
#include <sstream>
#include <string>

namespace v2ray_box {
namespace {

constexpr const char* kProxySchema = "org.gnome.system.proxy";
constexpr const char* kHttpProxySchema = "org.gnome.system.proxy.http";
constexpr const char* kHttpsProxySchema = "org.gnome.system.proxy.https";

std::string BackupPath() {
  return JoinPath(GetWorkingDirectory(), "proxy_backup.env");
}

void WriteBackup(const std::string& content) {
  std::ofstream out(BackupPath(), std::ios::trunc);
  if (!out.is_open()) {
    return;
  }
  out << content;
}

std::string ReadBackup() {
  std::ifstream in(BackupPath());
  if (!in.is_open()) {
    return "";
  }
  std::ostringstream buffer;
  buffer << in.rdbuf();
  return buffer.str();
}

void RemoveBackup() {
  RemoveFileIfExists(BackupPath());
}

std::string ReadSettingString(GSettings* settings, const char* key) {
  if (settings == nullptr) {
    return "";
  }
  gchar* value = g_settings_get_string(settings, key);
  if (value == nullptr) {
    return "";
  }
  const std::string result(value);
  g_free(value);
  return result;
}

int ReadSettingInt(GSettings* settings, const char* key) {
  if (settings == nullptr) {
    return 0;
  }
  return g_settings_get_int(settings, key);
}

bool ReadSettingBool(GSettings* settings, const char* key) {
  if (settings == nullptr) {
    return false;
  }
  return g_settings_get_boolean(settings, key);
}

void SyncSettings() {
  g_settings_sync();
}

void BackupCurrentSettings() {
  g_autoptr(GSettings) proxy = g_settings_new(kProxySchema);
  g_autoptr(GSettings) http = g_settings_new(kHttpProxySchema);
  g_autoptr(GSettings) https = g_settings_new(kHttpsProxySchema);

  std::ostringstream backup;
  backup << "mode=" << ReadSettingString(proxy, "mode") << '\n';
  backup << "http_host=" << ReadSettingString(http, "host") << '\n';
  backup << "http_port=" << ReadSettingInt(http, "port") << '\n';
  backup << "https_host=" << ReadSettingString(https, "host") << '\n';
  backup << "https_port=" << ReadSettingInt(https, "port") << '\n';
  backup << "http_user=" << ReadSettingString(http, "authentication-user")
         << '\n';
  backup << "http_password="
         << ReadSettingString(http, "authentication-password") << '\n';
  backup << "http_use_auth="
         << (ReadSettingBool(http, "use-authentication") ? "true" : "false")
         << '\n';
  WriteBackup(backup.str());
}

}  // namespace

bool ConfigOptionsSetSystemProxy(const std::string& json) {
  return json.find("\"set-system-proxy\":true") != std::string::npos ||
         json.find("\"set-system-proxy\": true") != std::string::npos;
}

bool SystemProxy::IsSupported() {
  g_autoptr(GSettings) proxy = g_settings_new(kProxySchema);
  return proxy != nullptr;
}

bool SystemProxy::Enable(const std::string& host,
                         int port,
                         const std::string& username,
                         const std::string& password) {
  if (!IsSupported() || port <= 0 || host.empty()) {
    return false;
  }

  if (ReadBackup().empty()) {
    BackupCurrentSettings();
  }

  g_autoptr(GSettings) proxy = g_settings_new(kProxySchema);
  g_autoptr(GSettings) http = g_settings_new(kHttpProxySchema);
  g_autoptr(GSettings) https = g_settings_new(kHttpsProxySchema);
  if (proxy == nullptr || http == nullptr || https == nullptr) {
    return false;
  }

  g_settings_set_string(http, "host", host.c_str());
  g_settings_set_int(http, "port", port);
  g_settings_set_boolean(http, "enabled", TRUE);
  g_settings_set_string(https, "host", host.c_str());
  g_settings_set_int(https, "port", port);

  if (!username.empty()) {
    g_settings_set_boolean(http, "use-authentication", TRUE);
    g_settings_set_string(http, "authentication-user", username.c_str());
    g_settings_set_string(http, "authentication-password", password.c_str());
  } else {
    g_settings_set_boolean(http, "use-authentication", FALSE);
  }

  g_settings_set_string(proxy, "mode", "manual");
  SyncSettings();
  return ReadSettingString(proxy, "mode") == "manual";
}

bool SystemProxy::Disable() {
  if (!IsSupported()) {
    return false;
  }

  const std::string backup = ReadBackup();
  g_autoptr(GSettings) proxy = g_settings_new(kProxySchema);
  g_autoptr(GSettings) http = g_settings_new(kHttpProxySchema);
  g_autoptr(GSettings) https = g_settings_new(kHttpsProxySchema);
  if (proxy == nullptr || http == nullptr || https == nullptr) {
    return false;
  }

  if (backup.empty()) {
    g_settings_set_string(proxy, "mode", "none");
    g_settings_set_boolean(http, "enabled", FALSE);
    SyncSettings();
    return true;
  }

  std::string mode = "none";
  std::string http_host;
  int http_port = 0;
  std::string https_host;
  int https_port = 0;
  std::string http_user;
  std::string http_password;
  bool http_use_auth = false;

  std::istringstream stream(backup);
  std::string line;
  while (std::getline(stream, line)) {
    const auto pos = line.find('=');
    if (pos == std::string::npos) {
      continue;
    }
    const std::string key = line.substr(0, pos);
    const std::string value = line.substr(pos + 1);
    if (key == "mode") {
      mode = value;
    } else if (key == "http_host") {
      http_host = value;
    } else if (key == "http_port") {
      http_port = std::stoi(value);
    } else if (key == "https_host") {
      https_host = value;
    } else if (key == "https_port") {
      https_port = std::stoi(value);
    } else if (key == "http_user") {
      http_user = value;
    } else if (key == "http_password") {
      http_password = value;
    } else if (key == "http_use_auth") {
      http_use_auth = value == "true";
    }
  }

  if (mode.empty()) {
    mode = "none";
  }

  g_settings_set_string(proxy, "mode", mode.c_str());
  if (mode == "manual") {
    g_settings_set_string(http, "host", http_host.c_str());
    g_settings_set_int(http, "port", http_port);
    g_settings_set_string(https, "host", https_host.c_str());
    g_settings_set_int(https, "port", https_port);
    g_settings_set_boolean(http, "use-authentication", http_use_auth);
    g_settings_set_string(http, "authentication-user", http_user.c_str());
    g_settings_set_string(http, "authentication-password", http_password.c_str());
    g_settings_set_boolean(http, "enabled", TRUE);
  } else {
    g_settings_set_boolean(http, "enabled", FALSE);
  }

  SyncSettings();
  RemoveBackup();
  return true;
}

}  // namespace v2ray_box
