library v2ray_box;

import 'src/models/vpn_status.dart';
import 'src/models/vpn_stats.dart';
import 'src/models/vpn_config.dart';
import 'src/models/app_info.dart';
import 'src/models/config_options.dart';
import 'src/models/total_traffic.dart';
import 'v2ray_box_platform_interface.dart';

// Export all models
export 'src/models/vpn_status.dart';
export 'src/models/vpn_stats.dart';
export 'src/models/vpn_config.dart';
export 'src/models/app_info.dart';
export 'src/models/config_options.dart';
export 'src/models/total_traffic.dart';

/// V2Ray Box - A Flutter plugin for V2Ray VPN functionality
class V2rayBox {
  static final V2rayBox _instance = V2rayBox._();

  factory V2rayBox() => _instance;

  V2rayBox._();

  bool _isInitialized = false;
  ConfigOptions _configOptions = const ConfigOptions();

  /// Get platform version
  Future<String?> getPlatformVersion() {
    return V2rayBoxPlatform.instance.getPlatformVersion();
  }

  /// Initialize the VPN core
  /// Must be called before any other methods
  /// [notificationStopButtonText] - Custom text for the stop button in notification (default: "Stop")
  /// [notificationIconName] - Custom notification icon name (drawable resource name without extension). If not set, app's default icon will be used.
  Future<void> initialize({
    String? notificationStopButtonText,
    String? notificationIconName,
  }) async {
    if (_isInitialized) return;
    await V2rayBoxPlatform.instance.setup();
    await setConfigOptions(_configOptions);
    if (notificationStopButtonText != null) {
      await setNotificationStopButtonText(notificationStopButtonText);
    }
    if (notificationIconName != null) {
      await setNotificationIcon(notificationIconName);
    }
    _isInitialized = true;
  }

  /// Set notification stop button text
  /// This should be called during initialization or before connecting
  Future<bool> setNotificationStopButtonText(String text) {
    return V2rayBoxPlatform.instance.setNotificationStopButtonText(text);
  }

  /// Set notification title
  /// If not set, the config name/remark will be used
  Future<bool> setNotificationTitle(String title) {
    return V2rayBoxPlatform.instance.setNotificationTitle(title);
  }

  /// Set notification icon
  /// [iconName] - Drawable resource name without extension. If not set or empty, app's default icon will be used.
  Future<bool> setNotificationIcon(String iconName) {
    return V2rayBoxPlatform.instance.setNotificationIcon(iconName);
  }

  /// Set configuration options for the VPN service
  Future<bool> setConfigOptions(ConfigOptions options) async {
    _configOptions = options;
    return V2rayBoxPlatform.instance.changeConfigOptions(
      options.toJsonString(),
    );
  }

  /// Get current configuration options
  ConfigOptions get configOptions => _configOptions;

  /// Parse and validate a config link
  /// Returns empty string if valid, error message otherwise
  Future<String> parseConfig(String configLink, {bool debug = false}) {
    return V2rayBoxPlatform.instance.parseConfig(configLink, debug: debug);
  }

  /// Generate full Xray config JSON from link
  Future<String> generateConfig(String configLink) {
    return V2rayBoxPlatform.instance.generateConfig(configLink);
  }

  /// Start VPN connection with the given config link
  /// [configLink] - The config link (vless://, vmess://, etc.)
  /// [name] - Display name for the profile (used as notification title if notificationTitle not set)
  /// [notificationTitle] - Optional custom notification title
  Future<bool> connect(
    String configLink, {
    String name = '',
    String? notificationTitle,
  }) async {
    if (notificationTitle != null) {
      await setNotificationTitle(notificationTitle);
    } else {
      // Clear custom title so profile name is used
      await setNotificationTitle('');
    }
    return V2rayBoxPlatform.instance.start(configLink, name);
  }

  /// Stop VPN connection
  Future<bool> disconnect() {
    return V2rayBoxPlatform.instance.stop();
  }

  /// Restart VPN connection
  Future<bool> restart(String configLink, {String name = ''}) {
    return V2rayBoxPlatform.instance.restart(configLink, name);
  }

  /// Check if VPN permission is granted
  Future<bool> checkVpnPermission() {
    return V2rayBoxPlatform.instance.checkVpnPermission();
  }

  /// Request VPN permission
  /// Returns true if permission was already granted, false if permission dialog was shown
  Future<bool> requestVpnPermission() {
    return V2rayBoxPlatform.instance.requestVpnPermission();
  }

  /// Set VPN service mode
  Future<bool> setServiceMode(VpnMode mode) {
    return V2rayBoxPlatform.instance.setServiceMode(mode);
  }

  /// Get current VPN service mode
  Future<VpnMode> getServiceMode() {
    return V2rayBoxPlatform.instance.getServiceMode();
  }

  /// Test URL connectivity and return latency in milliseconds
  /// Returns -1 if the test fails
  /// [timeout] is optional, defaults to 7000 ms
  Future<int> ping(String link, {int timeout = 7000}) {
    return V2rayBoxPlatform.instance.urlTest(link, timeout: timeout);
  }

  /// Test multiple URLs simultaneously and return latencies
  /// Returns a map of link -> latency in milliseconds
  /// [timeout] is optional, defaults to 7000 ms per config
  Future<Map<String, int>> pingAll(List<String> links, {int timeout = 7000}) {
    return V2rayBoxPlatform.instance.urlTestAll(links, timeout: timeout);
  }

  /// Get list of installed applications
  Future<List<AppInfo>> getInstalledApps() {
    return V2rayBoxPlatform.instance.getInstalledPackages();
  }

  /// Get app icon as base64 encoded PNG
  Future<String?> getAppIcon(String packageName) {
    return V2rayBoxPlatform.instance.getPackageIcon(packageName);
  }

  /// Set per-app proxy mode
  Future<bool> setPerAppProxyMode(PerAppProxyMode mode) {
    return V2rayBoxPlatform.instance.setPerAppProxyMode(mode);
  }

  /// Get current per-app proxy mode
  Future<PerAppProxyMode> getPerAppProxyMode() {
    return V2rayBoxPlatform.instance.getPerAppProxyMode();
  }

  /// Set per-app proxy list for the given mode
  Future<bool> setPerAppProxyList(List<String> packages, PerAppProxyMode mode) {
    return V2rayBoxPlatform.instance.setPerAppProxyList(packages, mode);
  }

  /// Get per-app proxy list for the given mode
  Future<List<String>> getPerAppProxyList(PerAppProxyMode mode) {
    return V2rayBoxPlatform.instance.getPerAppProxyList(mode);
  }

  /// Watch VPN status changes
  Stream<VpnStatus> watchStatus() {
    return V2rayBoxPlatform.instance.watchStatus();
  }

  /// Watch VPN traffic statistics
  Stream<VpnStats> watchStats() {
    return V2rayBoxPlatform.instance.watchStats();
  }

  /// Watch VPN alerts
  Stream<Map<String, dynamic>> watchAlerts() {
    return V2rayBoxPlatform.instance.watchAlerts();
  }

  /// Watch individual ping results as they complete during pingAll
  /// Each event contains {'link': String, 'latency': int}
  Stream<Map<String, dynamic>> watchPingResults() {
    return V2rayBoxPlatform.instance.watchPingResults();
  }

  /// Parse a VPN config link and return VpnConfig object
  VpnConfig parseConfigLink(String link) {
    return VpnConfig.fromLink(link);
  }

  /// Check if a link is a valid V2Ray config link
  bool isValidConfigLink(String link) {
    return VpnConfig.isValidLink(link);
  }

  /// Get total traffic (persistent storage across sessions)
  /// Returns TotalTraffic object with upload, download, and total bytes
  Future<TotalTraffic> getTotalTraffic() async {
    final map = await V2rayBoxPlatform.instance.getTotalTraffic();
    return TotalTraffic(
      upload: map['upload'] ?? 0,
      download: map['download'] ?? 0,
    );
  }

  /// Reset total traffic to zero
  /// This clears the persistent storage of cumulative traffic
  Future<bool> resetTotalTraffic() {
    return V2rayBoxPlatform.instance.resetTotalTraffic();
  }

  /// Get core engine information (version, engine type, etc.)
  Future<Map<String, dynamic>> getCoreInfo() {
    return V2rayBoxPlatform.instance.getCoreInfo();
  }

  /// Set the active core engine ('xray' or 'singbox')
  Future<bool> setCoreEngine(String engine) {
    return V2rayBoxPlatform.instance.setCoreEngine(engine);
  }

  /// Get the active core engine
  Future<String> getCoreEngine() {
    return V2rayBoxPlatform.instance.getCoreEngine();
  }

  /// Validate a raw Xray JSON config
  /// Returns empty string if valid, error message otherwise
  Future<String> checkConfigJson(String configJson) {
    return V2rayBoxPlatform.instance.checkConfigJson(configJson);
  }

  /// Start VPN with a raw Xray JSON config (bypasses link parsing)
  /// Useful when you want to edit the config before connecting
  Future<bool> connectWithJson(String configJson, {String name = ''}) {
    return V2rayBoxPlatform.instance.startWithJson(configJson, name);
  }

  /// Get current log buffer
  Future<List<String>> getLogs() {
    return V2rayBoxPlatform.instance.getLogs();
  }

  /// Clear current log buffer on both app side and native side
  Future<bool> clearLogs() {
    return V2rayBoxPlatform.instance.clearLogs();
  }

  /// Watch live log stream from the core engine
  Stream<Map<String, dynamic>> watchLogs() {
    return V2rayBoxPlatform.instance.watchLogs();
  }

  /// Enable or disable debug mode for verbose logging
  Future<bool> setDebugMode(bool enabled) {
    return V2rayBoxPlatform.instance.setDebugMode(enabled);
  }

  /// Get current debug mode state
  Future<bool> getDebugMode() {
    return V2rayBoxPlatform.instance.getDebugMode();
  }

  /// Format bytes to human-readable string using the core's formatter
  Future<String> formatBytes(int bytes) {
    return V2rayBoxPlatform.instance.formatBytes(bytes);
  }

  /// Get the currently active Xray JSON config
  /// Returns the full JSON config that is being used, or empty string if none
  Future<String> getActiveConfig() {
    return V2rayBoxPlatform.instance.getActiveConfig();
  }

  /// Get display name for a proxy type (e.g. "shadowsocks" -> "Shadowsocks")
  Future<String> proxyDisplayType(String type) {
    return V2rayBoxPlatform.instance.proxyDisplayType(type);
  }

  /// Format/prettify a JSON config
  Future<String> formatConfig(String configJson) {
    return V2rayBoxPlatform.instance.formatConfig(configJson);
  }

  /// Find an available network port starting from [startPort]
  Future<int> availablePort({int startPort = 2080}) {
    return V2rayBoxPlatform.instance.availablePort(startPort);
  }

  /// Select an outbound in an outbound group (requires active connection)
  Future<bool> selectOutbound(String groupTag, String outboundTag) {
    return V2rayBoxPlatform.instance.selectOutbound(groupTag, outboundTag);
  }

  /// Set clash routing mode (e.g. "rule", "global", "direct")
  /// Requires active connection with clash mode support
  Future<bool> setClashMode(String mode) {
    return V2rayBoxPlatform.instance.setClashMode(mode);
  }

  /// Parse a subscription/remote profile import link
  /// Returns map with 'name', 'url', 'host' keys
  Future<Map<String, dynamic>> parseSubscription(String link) {
    return V2rayBoxPlatform.instance.parseSubscription(link);
  }

  /// Generate a subscription import link from name and URL
  Future<String> generateSubscriptionLink(String name, String url) {
    return V2rayBoxPlatform.instance.generateSubscriptionLink(name, url);
  }

  /// Set the locale for the core library
  Future<bool> setLocale(String locale) {
    return V2rayBoxPlatform.instance.setLocale(locale);
  }

  /// Set the URL used for ping/latency testing
  /// Default is "https://www.gstatic.com/generate_204"
  Future<bool> setPingTestUrl(String url) {
    return V2rayBoxPlatform.instance.setPingTestUrl(url);
  }

  /// Get the current URL used for ping/latency testing
  Future<String> getPingTestUrl() {
    return V2rayBoxPlatform.instance.getPingTestUrl();
  }
}
