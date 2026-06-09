#include "include/v2ray_box/v2ray_box_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>
#include <fstream>
#include <sstream>
#include <string>

#include "desktop_core.h"
#include "system_proxy.h"
#include "v2ray_box_plugin_private.h"

#define V2RAY_BOX_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), v2ray_box_plugin_get_type(), V2rayBoxPlugin))

struct _V2rayBoxPlugin {
  GObject parent_instance;
  FlMethodChannel* method_channel;
  FlMethodChannel* credentials_channel;
  FlEventChannel* status_channel;
  FlEventChannel* stats_channel;
  FlEventChannel* alerts_channel;
  FlEventChannel* ping_channel;
  FlEventChannel* logs_channel;
  gboolean is_running;
  gboolean emit_status_events;
};

G_DEFINE_TYPE(V2rayBoxPlugin, v2ray_box_plugin, g_object_get_type())

namespace {

std::string g_core_engine = "xray";
std::string g_service_mode = "proxy";
std::string g_config_options = "{}";
std::string g_socks_user;
std::string g_socks_pass;
int g_socks_port = 1080;

FlMethodResponse* make_success_bool(bool value) {
  g_autoptr(FlValue) result = fl_value_new_bool(value ? TRUE : FALSE);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* make_success_string(const std::string& value) {
  g_autoptr(FlValue) result = fl_value_new_string(value.c_str());
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* make_error(const char* code, const char* message) {
  return FL_METHOD_RESPONSE(fl_method_error_response_new(code, message, nullptr));
}

void emit_status(V2rayBoxPlugin* self, const char* status) {
  if (!self->emit_status_events || self->status_channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "status", fl_value_new_string(status));
  fl_event_channel_send(self->status_channel, map, nullptr, nullptr);
}

void clear_session_credentials() {
  g_socks_user.clear();
  g_socks_pass.clear();
  g_socks_port = 1080;
  unsetenv("SECURE_VPN_SOCKS_USER");
  unsetenv("SECURE_VPN_SOCKS_PASS");
  unsetenv("SECURE_VPN_SOCKS_PORT");
}

void apply_session_credentials() {
  if (!g_socks_user.empty()) {
    setenv("SECURE_VPN_SOCKS_USER", g_socks_user.c_str(), 1);
  }
  if (!g_socks_pass.empty()) {
    setenv("SECURE_VPN_SOCKS_PASS", g_socks_pass.c_str(), 1);
  }
  setenv("SECURE_VPN_SOCKS_PORT", std::to_string(g_socks_port).c_str(), 1);
}

std::string active_config_path() {
  return v2ray_box::JoinPath(v2ray_box::GetWorkingDirectory(), "profiles/active_config.json");
}

void wipe_sensitive_files() {
  v2ray_box::RemoveFileIfExists(active_config_path());
  v2ray_box::RemoveFileIfExists(
      v2ray_box::JoinPath(v2ray_box::GetWorkingDirectory(), "singbox_config.json"));
}

}  // namespace

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar* version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodErrorResponse* v2ray_box_status_listen_cb(FlEventChannel* channel,
                                                         FlValue* args,
                                                         gpointer user_data) {
  V2rayBoxPlugin* self = V2RAY_BOX_PLUGIN(user_data);
  self->emit_status_events = TRUE;
  emit_status(self, self->is_running ? "Started" : "Stopped");
  return nullptr;
}

static FlMethodErrorResponse* v2ray_box_status_cancel_cb(FlEventChannel* channel,
                                                         FlValue* args,
                                                         gpointer user_data) {
  V2rayBoxPlugin* self = V2RAY_BOX_PLUGIN(user_data);
  self->emit_status_events = FALSE;
  return nullptr;
}

static FlMethodErrorResponse* v2ray_box_noop_listen_cb(FlEventChannel* channel,
                                                       FlValue* args,
                                                       gpointer user_data) {
  return nullptr;
}

static FlMethodErrorResponse* v2ray_box_noop_cancel_cb(FlEventChannel* channel,
                                                       FlValue* args,
                                                       gpointer user_data) {
  return nullptr;
}

static void handle_credentials_call(FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "setSessionCredentials") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* username = fl_value_lookup_string(args, "username");
    FlValue* password = fl_value_lookup_string(args, "password");
    FlValue* port = fl_value_lookup_string(args, "port");
    g_socks_user = fl_value_get_type(username) == FL_VALUE_TYPE_STRING
                       ? fl_value_get_string(username)
                       : "";
    g_socks_pass = fl_value_get_type(password) == FL_VALUE_TYPE_STRING
                       ? fl_value_get_string(password)
                       : "";
    if (fl_value_get_type(port) == FL_VALUE_TYPE_INT) {
      g_socks_port = static_cast<int>(fl_value_get_int(port));
    }
    apply_session_credentials();
    response = make_success_bool(true);
  } else if (strcmp(method, "clearSessionCredentials") == 0) {
    clear_session_credentials();
    wipe_sensitive_files();
    response = make_success_bool(true);
  } else if (strcmp(method, "getLocalSocksPort") == 0) {
    g_autoptr(FlValue) result = fl_value_new_int(g_socks_port);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void v2ray_box_plugin_handle_method_call(V2rayBoxPlugin* self,
                                                FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "setup") == 0) {
    const std::string work_dir = v2ray_box::GetWorkingDirectory();
    if (!v2ray_box::EnsureDirectory(work_dir) ||
        !v2ray_box::EnsureDirectory(v2ray_box::JoinPath(work_dir, "profiles"))) {
      response = make_error("SETUP_ERROR", "Failed to create working directories");
    } else {
      const std::string xray_binary =
          v2ray_box::DesktopCore::Instance().FindBinary("xray");
      if (!xray_binary.empty()) {
        v2ray_box::EnsureXrayGeoAssets(work_dir, xray_binary);
      }
      response = make_success_string("");
    }
  } else if (strcmp(method, "change_config_options") == 0) {
    if (fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      g_config_options = fl_value_get_string(args);
    }
    response = make_success_bool(true);
  } else if (strcmp(method, "set_core_engine") == 0) {
    if (fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      g_core_engine = fl_value_get_string(args);
    }
    response = make_success_bool(true);
  } else if (strcmp(method, "get_core_engine") == 0) {
    response = make_success_string(g_core_engine);
  } else if (strcmp(method, "set_service_mode") == 0) {
    if (fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      g_service_mode = fl_value_get_string(args);
    }
    response = make_success_bool(true);
  } else if (strcmp(method, "get_service_mode") == 0) {
    response = make_success_string(g_service_mode);
  } else if (strcmp(method, "check_vpn_permission") == 0 ||
             strcmp(method, "request_vpn_permission") == 0) {
    response = make_success_bool(true);
  } else if (strcmp(method, "set_notification_stop_button_text") == 0 ||
             strcmp(method, "set_notification_title") == 0 ||
             strcmp(method, "set_notification_icon") == 0 ||
             strcmp(method, "set_debug_mode") == 0 ||
             strcmp(method, "set_locale") == 0 ||
             strcmp(method, "set_ping_test_url") == 0 ||
             strcmp(method, "set_per_app_proxy_mode") == 0 ||
             strcmp(method, "set_per_app_proxy_list") == 0) {
    response = make_success_bool(true);
  } else if (strcmp(method, "get_debug_mode") == 0) {
    response = make_success_bool(false);
  } else if (strcmp(method, "get_per_app_proxy_mode") == 0) {
    response = make_success_string("off");
  } else if (strcmp(method, "get_per_app_proxy_list") == 0) {
    g_autoptr(FlValue) list = fl_value_new_list();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(list));
  } else if (strcmp(method, "parse_config") == 0) {
    response = make_success_string("");
  } else if (strcmp(method, "generate_config") == 0) {
    response = make_error(
        "NOT_SUPPORTED",
        "generate_config is not supported on Linux. Use subscription JSON.");
  } else if (strcmp(method, "check_config_json") == 0) {
    const char* json = fl_value_get_type(args) == FL_VALUE_TYPE_STRING
                           ? fl_value_get_string(args)
                           : "";
    response = v2ray_box::IsValidJson(json)
                   ? make_success_string("")
                   : make_error("INVALID_CONFIG", "Invalid JSON format");
  } else if (strcmp(method, "start_with_json") == 0) {
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      response = make_error("INVALID_ARGS", "Missing config parameter");
    } else {
      FlValue* config = fl_value_lookup_string(args, "config");
      const char* config_json = fl_value_get_type(config) == FL_VALUE_TYPE_STRING
                                    ? fl_value_get_string(config)
                                    : nullptr;
      if (config_json == nullptr || !v2ray_box::IsValidJson(config_json)) {
        response = make_error("INVALID_CONFIG", "Config validation failed");
      } else {
        emit_status(self, "Starting");
        const std::string profiles_dir =
            v2ray_box::JoinPath(v2ray_box::GetWorkingDirectory(), "profiles");
        const std::string path =
            v2ray_box::JoinPath(profiles_dir, "active_config.json");
        if (!v2ray_box::EnsureDirectory(profiles_dir)) {
          emit_status(self, "Stopped");
          response = make_error("START_ERROR", "Failed to create profiles directory");
        } else if (!v2ray_box::WriteTextFile(path, config_json)) {
          emit_status(self, "Stopped");
          const std::string write_error =
              "Failed to write config file: " + path;
          response = make_error("START_ERROR", write_error.c_str());
        } else {
          FlValue* socks_username = fl_value_lookup_string(args, "socksUsername");
          FlValue* socks_password = fl_value_lookup_string(args, "socksPassword");
          FlValue* socks_port_val = fl_value_lookup_string(args, "socksPort");
          if (fl_value_get_type(socks_username) == FL_VALUE_TYPE_STRING) {
            g_socks_user = fl_value_get_string(socks_username);
          }
          if (fl_value_get_type(socks_password) == FL_VALUE_TYPE_STRING) {
            g_socks_pass = fl_value_get_string(socks_password);
          }
          if (fl_value_get_type(socks_port_val) == FL_VALUE_TYPE_INT) {
            g_socks_port = static_cast<int>(fl_value_get_int(socks_port_val));
          }
          apply_session_credentials();
          const std::string start_error = v2ray_box::DesktopCore::Instance().Start(
              g_core_engine, path, v2ray_box::GetWorkingDirectory());
          if (start_error.empty()) {
            self->is_running = TRUE;
            if (v2ray_box::ConfigOptionsSetSystemProxy(g_config_options) &&
                !g_socks_user.empty()) {
              v2ray_box::SystemProxy::Enable("127.0.0.1", g_socks_port + 1,
                                             g_socks_user, g_socks_pass);
            }
            emit_status(self, "Started");
            response = make_success_bool(true);
          } else {
            self->is_running = FALSE;
            wipe_sensitive_files();
            emit_status(self, "Stopped");
            response = make_error("START_ERROR", start_error.c_str());
          }
        }
      }
    }
  } else if (strcmp(method, "stop") == 0) {
    emit_status(self, "Stopping");
    v2ray_box::SystemProxy::Disable();
    v2ray_box::DesktopCore::Instance().Stop();
    self->is_running = FALSE;
    clear_session_credentials();
    wipe_sensitive_files();
    emit_status(self, "Stopped");
    response = make_success_bool(true);
  } else if (strcmp(method, "get_core_info") == 0) {
    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "engine", fl_value_new_string(g_core_engine.c_str()));
    fl_value_set_string_take(
        map, "version",
        fl_value_new_string(
            v2ray_box::DesktopCore::Instance().GetVersion(g_core_engine).c_str()));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(map));
  } else if (strcmp(method, "get_logs") == 0) {
    g_autoptr(FlValue) list = fl_value_new_list();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(list));
  } else if (strcmp(method, "get_active_config") == 0) {
    std::ifstream in(active_config_path());
    std::ostringstream buffer;
    if (in.is_open()) {
      buffer << in.rdbuf();
    }
    response = make_success_string(buffer.str());
  } else if (strcmp(method, "get_total_traffic") == 0) {
    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "upload", fl_value_new_int(0));
    fl_value_set_string_take(map, "download", fl_value_new_int(0));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(map));
  } else if (strcmp(method, "reset_total_traffic") == 0 ||
             strcmp(method, "clear_logs") == 0) {
    response = make_success_bool(true);
  } else if (strcmp(method, "url_test") == 0 ||
             strcmp(method, "url_test_all") == 0 ||
             strcmp(method, "start") == 0 ||
             strcmp(method, "restart") == 0) {
    response = make_error("NOT_SUPPORTED", "Method not supported on Linux desktop");
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  v2ray_box_plugin_handle_method_call(V2RAY_BOX_PLUGIN(user_data), method_call);
}

static void credentials_call_cb(FlMethodChannel* channel,
                                FlMethodCall* method_call,
                                gpointer user_data) {
  handle_credentials_call(method_call);
}

static void v2ray_box_plugin_dispose(GObject* object) {
  V2rayBoxPlugin* self = V2RAY_BOX_PLUGIN(object);
  g_clear_object(&self->method_channel);
  g_clear_object(&self->credentials_channel);
  g_clear_object(&self->status_channel);
  g_clear_object(&self->stats_channel);
  g_clear_object(&self->alerts_channel);
  g_clear_object(&self->ping_channel);
  g_clear_object(&self->logs_channel);
  v2ray_box::SystemProxy::Disable();
  v2ray_box::DesktopCore::Instance().Stop();
  G_OBJECT_CLASS(v2ray_box_plugin_parent_class)->dispose(object);
}

static void v2ray_box_plugin_class_init(V2rayBoxPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = v2ray_box_plugin_dispose;
}

static void v2ray_box_plugin_init(V2rayBoxPlugin* self) {
  self->is_running = FALSE;
  self->emit_status_events = FALSE;
}

void v2ray_box_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  V2rayBoxPlugin* plugin = V2RAY_BOX_PLUGIN(
      g_object_new(v2ray_box_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlJsonMethodCodec) json_codec = fl_json_method_codec_new();

  plugin->method_channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "v2ray_box", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->method_channel, method_call_cb,
                                          g_object_ref(plugin), g_object_unref);

  plugin->credentials_channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "secure_vpn/credentials",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->credentials_channel,
                                          credentials_call_cb, nullptr, nullptr);

  plugin->status_channel = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "v2ray_box/status",
      FL_METHOD_CODEC(json_codec));
  fl_event_channel_set_stream_handlers(plugin->status_channel,
                                       v2ray_box_status_listen_cb,
                                       v2ray_box_status_cancel_cb, g_object_ref(plugin),
                                       g_object_unref);

  plugin->stats_channel = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "v2ray_box/stats",
      FL_METHOD_CODEC(json_codec));
  fl_event_channel_set_stream_handlers(plugin->stats_channel, v2ray_box_noop_listen_cb,
                                       v2ray_box_noop_cancel_cb, nullptr, nullptr);

  plugin->alerts_channel = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "v2ray_box/alerts",
      FL_METHOD_CODEC(json_codec));
  fl_event_channel_set_stream_handlers(plugin->alerts_channel, v2ray_box_noop_listen_cb,
                                       v2ray_box_noop_cancel_cb, nullptr, nullptr);

  plugin->ping_channel = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "v2ray_box/ping",
      FL_METHOD_CODEC(json_codec));
  fl_event_channel_set_stream_handlers(plugin->ping_channel, v2ray_box_noop_listen_cb,
                                       v2ray_box_noop_cancel_cb, nullptr, nullptr);

  plugin->logs_channel = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "v2ray_box/logs",
      FL_METHOD_CODEC(json_codec));
  fl_event_channel_set_stream_handlers(plugin->logs_channel, v2ray_box_noop_listen_cb,
                                       v2ray_box_noop_cancel_cb, nullptr, nullptr);

  g_object_unref(plugin);
}
