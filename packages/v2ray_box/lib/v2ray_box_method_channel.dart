import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/models/vpn_status.dart';
import 'src/models/vpn_stats.dart';
import 'src/models/app_info.dart';
import 'v2ray_box_platform_interface.dart';

/// An implementation of [V2rayBoxPlatform] that uses method channels.
class MethodChannelV2rayBox extends V2rayBoxPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('v2ray_box');

  final statusChannel = const EventChannel(
    'v2ray_box/status',
    JSONMethodCodec(),
  );

  final alertsChannel = const EventChannel(
    'v2ray_box/alerts',
    JSONMethodCodec(),
  );

  final statsChannel = const EventChannel('v2ray_box/stats', JSONMethodCodec());

  final pingChannel = const EventChannel('v2ray_box/ping', JSONMethodCodec());

  final logsChannel = const EventChannel('v2ray_box/logs', JSONMethodCodec());

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<void> setup() async {
    await methodChannel.invokeMethod('setup');
  }

  @override
  Future<String> parseConfig(String configLink, {bool debug = false}) async {
    final result = await methodChannel.invokeMethod<String>('parse_config', {
      'link': configLink,
      'debug': debug,
    });
    return result ?? '';
  }

  @override
  Future<bool> changeConfigOptions(String optionsJson) async {
    final result = await methodChannel.invokeMethod<bool>(
      'change_config_options',
      optionsJson,
    );
    return result ?? false;
  }

  @override
  Future<String> generateConfig(String configLink) async {
    final result = await methodChannel.invokeMethod<String>('generate_config', {
      'link': configLink,
    });
    return result ?? '';
  }

  @override
  Future<bool> start(String configLink, String name) async {
    final result = await methodChannel.invokeMethod<bool>('start', {
      'link': configLink,
      'name': name,
    });
    return result ?? false;
  }

  @override
  Future<bool> stop() async {
    final result = await methodChannel.invokeMethod<bool>('stop');
    return result ?? false;
  }

  @override
  Future<bool> restart(String configLink, String name) async {
    final result = await methodChannel.invokeMethod<bool>('restart', {
      'link': configLink,
      'name': name,
    });
    return result ?? false;
  }

  @override
  Future<bool> checkVpnPermission() async {
    final result = await methodChannel.invokeMethod<bool>(
      'check_vpn_permission',
    );
    return result ?? false;
  }

  @override
  Future<bool> requestVpnPermission() async {
    final result = await methodChannel.invokeMethod<bool>(
      'request_vpn_permission',
    );
    return result ?? false;
  }

  @override
  Future<bool> setServiceMode(VpnMode mode) async {
    final result = await methodChannel.invokeMethod<bool>(
      'set_service_mode',
      mode.value,
    );
    return result ?? false;
  }

  @override
  Future<VpnMode> getServiceMode() async {
    final result = await methodChannel.invokeMethod<String>('get_service_mode');
    return VpnMode.fromString(result);
  }

  @override
  Future<bool> setNotificationStopButtonText(String text) async {
    final result = await methodChannel.invokeMethod<bool>(
      'set_notification_stop_button_text',
      text,
    );
    return result ?? false;
  }

  @override
  Future<bool> setNotificationTitle(String title) async {
    final result = await methodChannel.invokeMethod<bool>(
      'set_notification_title',
      title,
    );
    return result ?? false;
  }

  @override
  Future<bool> setNotificationIcon(String iconName) async {
    final result = await methodChannel.invokeMethod<bool>(
      'set_notification_icon',
      iconName,
    );
    return result ?? false;
  }

  @override
  Future<List<AppInfo>> getInstalledPackages() async {
    final result = await methodChannel.invokeMethod<String>(
      'get_installed_packages',
    );
    if (result == null || result.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(result);
    return jsonList
        .map((e) => AppInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<String?> getPackageIcon(String packageName) async {
    final result = await methodChannel.invokeMethod<String>(
      'get_package_icon',
      {'packageName': packageName},
    );
    return result;
  }

  @override
  Future<int> urlTest(String link, {int timeout = 7000}) async {
    final result = await methodChannel.invokeMethod<dynamic>('url_test', {
      'link': link,
      'timeout': timeout,
    });
    if (result is int) return result;
    if (result is double) return result.toInt();
    return -1;
  }

  @override
  Future<Map<String, int>> urlTestAll(
    List<String> links, {
    int timeout = 7000,
  }) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'url_test_all',
      {'links': links, 'timeout': timeout},
    );
    if (result == null) return {};
    return result.map((key, value) {
      final intValue = value is int ? value : (value as num).toInt();
      return MapEntry(key.toString(), intValue);
    });
  }

  @override
  Future<bool> setPerAppProxyMode(PerAppProxyMode mode) async {
    final result = await methodChannel.invokeMethod<bool>(
      'set_per_app_proxy_mode',
      mode.value,
    );
    return result ?? false;
  }

  @override
  Future<PerAppProxyMode> getPerAppProxyMode() async {
    final result = await methodChannel.invokeMethod<String>(
      'get_per_app_proxy_mode',
    );
    return PerAppProxyMode.fromString(result);
  }

  @override
  Future<bool> setPerAppProxyList(
    List<String> packages,
    PerAppProxyMode mode,
  ) async {
    final result = await methodChannel.invokeMethod<bool>(
      'set_per_app_proxy_list',
      {'list': packages, 'mode': mode.value},
    );
    return result ?? false;
  }

  @override
  Future<List<String>> getPerAppProxyList(PerAppProxyMode mode) async {
    final result = await methodChannel.invokeMethod<List<dynamic>>(
      'get_per_app_proxy_list',
      {'mode': mode.value},
    );
    if (result == null) return [];
    return result.map((e) => e.toString()).toList();
  }

  @override
  Stream<VpnStatus> watchStatus() {
    return statusChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return VpnStatus.fromString(event['status']?.toString());
      }
      return VpnStatus.stopped;
    });
  }

  @override
  Stream<VpnStats> watchStats() {
    return statsChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        // Convert Map<dynamic, dynamic> to Map<String, dynamic>
        final map = Map<String, dynamic>.from(event);
        return VpnStats.fromJson(map);
      }
      return const VpnStats();
    });
  }

  @override
  Stream<Map<String, dynamic>> watchAlerts() {
    return alertsChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{};
    });
  }

  @override
  Stream<Map<String, dynamic>> watchPingResults() {
    return pingChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{};
    });
  }

  @override
  Future<Map<String, int>> getTotalTraffic() async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'get_total_traffic',
    );
    if (result == null) return {'upload': 0, 'download': 0};
    return {
      'upload': (result['upload'] as num?)?.toInt() ?? 0,
      'download': (result['download'] as num?)?.toInt() ?? 0,
    };
  }

  @override
  Future<bool> resetTotalTraffic() async {
    final result = await methodChannel.invokeMethod<bool>(
      'reset_total_traffic',
    );
    return result ?? false;
  }

  @override
  Future<Map<String, dynamic>> getCoreInfo() async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'get_core_info',
    );
    if (result == null) return {};
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<bool> setCoreEngine(String engine) async {
    final result = await methodChannel.invokeMethod<bool>(
      'set_core_engine',
      engine,
    );
    return result ?? false;
  }

  @override
  Future<String> getCoreEngine() async {
    final result = await methodChannel.invokeMethod<String>('get_core_engine');
    return result ?? 'xray';
  }

  @override
  Future<String> checkConfigJson(String configJson) async {
    final result = await methodChannel.invokeMethod<String>(
      'check_config_json',
      configJson,
    );
    return result ?? '';
  }

  @override
  Future<bool> startWithJson(String configJson, String name) async {
    final result = await methodChannel.invokeMethod<bool>('start_with_json', {
      'config': configJson,
      'name': name,
    });
    return result ?? false;
  }

  @override
  Future<List<String>> getLogs() async {
    final result = await methodChannel.invokeMethod<List<dynamic>>('get_logs');
    if (result == null) return [];
    return result.map((e) => e.toString()).toList();
  }

  @override
  Future<bool> clearLogs() async {
    final result = await methodChannel.invokeMethod<bool>('clear_logs');
    return result ?? false;
  }

  @override
  Stream<Map<String, dynamic>> watchLogs() {
    return logsChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{};
    });
  }

  @override
  Future<bool> setDebugMode(bool enabled) async {
    final result = await methodChannel.invokeMethod<bool>(
      'set_debug_mode',
      enabled,
    );
    return result ?? false;
  }

  @override
  Future<bool> getDebugMode() async {
    final result = await methodChannel.invokeMethod<bool>('get_debug_mode');
    return result ?? false;
  }

  @override
  Future<String> formatBytes(int bytes) async {
    final result = await methodChannel.invokeMethod<String>(
      'format_bytes',
      bytes,
    );
    return result ?? '0 B';
  }

  @override
  Future<String> getActiveConfig() async {
    final result = await methodChannel.invokeMethod<String>(
      'get_active_config',
    );
    return result ?? '';
  }

  @override
  Future<String> proxyDisplayType(String type) async {
    final result = await methodChannel.invokeMethod<String>(
      'proxy_display_type',
      type,
    );
    return result ?? type;
  }

  @override
  Future<String> formatConfig(String configJson) async {
    final result = await methodChannel.invokeMethod<String>(
      'format_config',
      configJson,
    );
    return result ?? configJson;
  }

  @override
  Future<int> availablePort(int startPort) async {
    final result = await methodChannel.invokeMethod<int>(
      'available_port',
      startPort,
    );
    return result ?? -1;
  }

  @override
  Future<bool> selectOutbound(String groupTag, String outboundTag) async {
    final result = await methodChannel.invokeMethod<bool>('select_outbound', {
      'group': groupTag,
      'outbound': outboundTag,
    });
    return result ?? false;
  }

  @override
  Future<bool> setClashMode(String mode) async {
    final result = await methodChannel.invokeMethod<bool>(
      'set_clash_mode',
      mode,
    );
    return result ?? false;
  }

  @override
  Future<Map<String, dynamic>> parseSubscription(String link) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'parse_subscription',
      link,
    );
    if (result == null) return {};
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<String> generateSubscriptionLink(String name, String url) async {
    final result = await methodChannel.invokeMethod<String>(
      'generate_subscription_link',
      {'name': name, 'url': url},
    );
    return result ?? '';
  }

  @override
  Future<bool> setLocale(String locale) async {
    final result = await methodChannel.invokeMethod<bool>('set_locale', locale);
    return result ?? false;
  }

  @override
  Future<bool> setPingTestUrl(String url) async {
    final result = await methodChannel.invokeMethod<bool>(
      'set_ping_test_url',
      url,
    );
    return result ?? false;
  }

  @override
  Future<String> getPingTestUrl() async {
    final result = await methodChannel.invokeMethod<String>(
      'get_ping_test_url',
    );
    return result ?? 'https://www.gstatic.com/generate_204';
  }
}
