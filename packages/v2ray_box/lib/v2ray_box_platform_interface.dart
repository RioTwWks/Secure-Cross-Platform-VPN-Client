import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/models/vpn_status.dart';
import 'src/models/vpn_stats.dart';
import 'src/models/app_info.dart';
import 'v2ray_box_method_channel.dart';

abstract class V2rayBoxPlatform extends PlatformInterface {
  V2rayBoxPlatform() : super(token: _token);

  static final Object _token = Object();

  static V2rayBoxPlatform _instance = MethodChannelV2rayBox();

  static V2rayBoxPlatform get instance => _instance;

  static set instance(V2rayBoxPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  /// Initialize the VPN core
  Future<void> setup() {
    throw UnimplementedError('setup() has not been implemented.');
  }

  /// Parse and validate a config link
  Future<String> parseConfig(String configLink, {bool debug = false}) {
    throw UnimplementedError('parseConfig() has not been implemented.');
  }

  /// Set configuration options
  Future<bool> changeConfigOptions(String optionsJson) {
    throw UnimplementedError('changeConfigOptions() has not been implemented.');
  }

  /// Generate full config from link
  Future<String> generateConfig(String configLink) {
    throw UnimplementedError('generateConfig() has not been implemented.');
  }

  /// Start VPN connection
  Future<bool> start(String configLink, String name) {
    throw UnimplementedError('start() has not been implemented.');
  }

  /// Stop VPN connection
  Future<bool> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }

  /// Restart VPN connection
  Future<bool> restart(String configLink, String name) {
    throw UnimplementedError('restart() has not been implemented.');
  }

  /// Check if VPN permission is granted
  Future<bool> checkVpnPermission() {
    throw UnimplementedError('checkVpnPermission() has not been implemented.');
  }

  /// Request VPN permission
  /// Returns true if permission was already granted, false if permission dialog was shown
  Future<bool> requestVpnPermission() {
    throw UnimplementedError(
      'requestVpnPermission() has not been implemented.',
    );
  }

  /// Set service mode (vpn or proxy)
  Future<bool> setServiceMode(VpnMode mode) {
    throw UnimplementedError('setServiceMode() has not been implemented.');
  }

  /// Get current service mode
  Future<VpnMode> getServiceMode() {
    throw UnimplementedError('getServiceMode() has not been implemented.');
  }

  /// Set notification stop button text
  Future<bool> setNotificationStopButtonText(String text) {
    throw UnimplementedError(
      'setNotificationStopButtonText() has not been implemented.',
    );
  }

  /// Set notification title (shown when connected)
  Future<bool> setNotificationTitle(String title) {
    throw UnimplementedError(
      'setNotificationTitle() has not been implemented.',
    );
  }

  /// Set notification icon (drawable resource name)
  Future<bool> setNotificationIcon(String iconName) {
    throw UnimplementedError('setNotificationIcon() has not been implemented.');
  }

  /// Get list of installed apps
  Future<List<AppInfo>> getInstalledPackages() {
    throw UnimplementedError(
      'getInstalledPackages() has not been implemented.',
    );
  }

  /// Get app icon as base64 string
  Future<String?> getPackageIcon(String packageName) {
    throw UnimplementedError('getPackageIcon() has not been implemented.');
  }

  /// Test URL connectivity and return latency in ms
  Future<int> urlTest(String link, {int timeout = 7000}) {
    throw UnimplementedError('urlTest() has not been implemented.');
  }

  /// Test multiple URLs and return latencies
  Future<Map<String, int>> urlTestAll(
    List<String> links, {
    int timeout = 7000,
  }) {
    throw UnimplementedError('urlTestAll() has not been implemented.');
  }

  /// Set per-app proxy mode
  Future<bool> setPerAppProxyMode(PerAppProxyMode mode) {
    throw UnimplementedError('setPerAppProxyMode() has not been implemented.');
  }

  /// Get per-app proxy mode
  Future<PerAppProxyMode> getPerAppProxyMode() {
    throw UnimplementedError('getPerAppProxyMode() has not been implemented.');
  }

  /// Set per-app proxy list
  Future<bool> setPerAppProxyList(List<String> packages, PerAppProxyMode mode) {
    throw UnimplementedError('setPerAppProxyList() has not been implemented.');
  }

  /// Get per-app proxy list
  Future<List<String>> getPerAppProxyList(PerAppProxyMode mode) {
    throw UnimplementedError('getPerAppProxyList() has not been implemented.');
  }

  /// Watch VPN status changes
  Stream<VpnStatus> watchStatus() {
    throw UnimplementedError('watchStatus() has not been implemented.');
  }

  /// Watch VPN traffic stats
  Stream<VpnStats> watchStats() {
    throw UnimplementedError('watchStats() has not been implemented.');
  }

  /// Watch VPN alerts
  Stream<Map<String, dynamic>> watchAlerts() {
    throw UnimplementedError('watchAlerts() has not been implemented.');
  }

  /// Watch individual ping results as they complete
  Stream<Map<String, dynamic>> watchPingResults() {
    throw UnimplementedError('watchPingResults() has not been implemented.');
  }

  /// Get total traffic (persistent storage)
  Future<Map<String, int>> getTotalTraffic() {
    throw UnimplementedError('getTotalTraffic() has not been implemented.');
  }

  /// Reset total traffic to zero
  Future<bool> resetTotalTraffic() {
    throw UnimplementedError('resetTotalTraffic() has not been implemented.');
  }

  /// Get core engine info (version, engine type)
  Future<Map<String, dynamic>> getCoreInfo() {
    throw UnimplementedError('getCoreInfo() has not been implemented.');
  }

  /// Set the active core engine ('xray' or 'singbox')
  Future<bool> setCoreEngine(String engine) {
    throw UnimplementedError('setCoreEngine() has not been implemented.');
  }

  /// Get the active core engine
  Future<String> getCoreEngine() {
    throw UnimplementedError('getCoreEngine() has not been implemented.');
  }

  /// Validate raw Xray JSON config
  Future<String> checkConfigJson(String configJson) {
    throw UnimplementedError('checkConfigJson() has not been implemented.');
  }

  /// Start VPN with raw Xray JSON config (bypassing link parsing)
  Future<bool> startWithJson(String configJson, String name) {
    throw UnimplementedError('startWithJson() has not been implemented.');
  }

  /// Get current log buffer
  Future<List<String>> getLogs() {
    throw UnimplementedError('getLogs() has not been implemented.');
  }

  /// Clear current log buffer
  Future<bool> clearLogs() {
    throw UnimplementedError('clearLogs() has not been implemented.');
  }

  /// Watch live log stream
  Stream<Map<String, dynamic>> watchLogs() {
    throw UnimplementedError('watchLogs() has not been implemented.');
  }

  /// Set debug mode
  Future<bool> setDebugMode(bool enabled) {
    throw UnimplementedError('setDebugMode() has not been implemented.');
  }

  /// Get debug mode
  Future<bool> getDebugMode() {
    throw UnimplementedError('getDebugMode() has not been implemented.');
  }

  /// Format bytes to human-readable string
  Future<String> formatBytes(int bytes) {
    throw UnimplementedError('formatBytes() has not been implemented.');
  }

  /// Get active config JSON
  Future<String> getActiveConfig() {
    throw UnimplementedError('getActiveConfig() has not been implemented.');
  }

  /// Get display name for proxy type
  Future<String> proxyDisplayType(String type) {
    throw UnimplementedError('proxyDisplayType() has not been implemented.');
  }

  /// Format config JSON (prettify)
  Future<String> formatConfig(String configJson) {
    throw UnimplementedError('formatConfig() has not been implemented.');
  }

  /// Find an available port starting from startPort
  Future<int> availablePort(int startPort) {
    throw UnimplementedError('availablePort() has not been implemented.');
  }

  /// Select outbound in an outbound group
  Future<bool> selectOutbound(String groupTag, String outboundTag) {
    throw UnimplementedError('selectOutbound() has not been implemented.');
  }

  /// Set clash mode (rule/global/direct)
  Future<bool> setClashMode(String mode) {
    throw UnimplementedError('setClashMode() has not been implemented.');
  }

  /// Parse a remote profile/subscription import link
  Future<Map<String, dynamic>> parseSubscription(String link) {
    throw UnimplementedError('parseSubscription() has not been implemented.');
  }

  /// Generate a subscription import link
  Future<String> generateSubscriptionLink(String name, String url) {
    throw UnimplementedError(
      'generateSubscriptionLink() has not been implemented.',
    );
  }

  /// Set the locale for the core library
  Future<bool> setLocale(String locale) {
    throw UnimplementedError('setLocale() has not been implemented.');
  }

  /// Set the URL used for ping testing
  Future<bool> setPingTestUrl(String url) {
    throw UnimplementedError('setPingTestUrl() has not been implemented.');
  }

  /// Get the URL used for ping testing
  Future<String> getPingTestUrl() {
    throw UnimplementedError('getPingTestUrl() has not been implemented.');
  }
}
