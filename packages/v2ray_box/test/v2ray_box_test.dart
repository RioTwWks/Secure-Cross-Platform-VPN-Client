import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_box/v2ray_box.dart';
import 'package:v2ray_box/v2ray_box_platform_interface.dart';
import 'package:v2ray_box/v2ray_box_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockV2rayBoxPlatform
    with MockPlatformInterfaceMixin
    implements V2rayBoxPlatform {
  String _coreEngine = 'xray';
  VpnMode _serviceMode = VpnMode.vpn;
  PerAppProxyMode _perAppMode = PerAppProxyMode.off;
  List<String> _includeList = [];
  List<String> _excludeList = [];
  bool _debugMode = false;
  String _pingTestUrl = 'http://connectivitycheck.gstatic.com/generate_204';
  String _notifStopText = 'Stop';
  String _notifTitle = '';
  String _notifIcon = '';
  String _locale = 'en';

  @override
  Future<String?> getPlatformVersion() async => 'Android 14';

  @override
  Future<void> setup() async {}

  @override
  Future<String> parseConfig(String configLink, {bool debug = false}) async =>
      '';

  @override
  Future<bool> changeConfigOptions(String optionsJson) async => true;

  @override
  Future<String> generateConfig(String configLink) async =>
      '{"outbounds":[]}';

  @override
  Future<bool> start(String configLink, String name) async => true;

  @override
  Future<bool> stop() async => true;

  @override
  Future<bool> restart(String configLink, String name) async => true;

  @override
  Future<bool> checkVpnPermission() async => true;

  @override
  Future<bool> requestVpnPermission() async => true;

  @override
  Future<bool> setServiceMode(VpnMode mode) async {
    _serviceMode = mode;
    return true;
  }

  @override
  Future<VpnMode> getServiceMode() async => _serviceMode;

  @override
  Future<bool> setNotificationStopButtonText(String text) async {
    _notifStopText = text;
    return true;
  }

  @override
  Future<bool> setNotificationTitle(String title) async {
    _notifTitle = title;
    return true;
  }

  @override
  Future<bool> setNotificationIcon(String iconName) async {
    _notifIcon = iconName;
    return true;
  }

  @override
  Future<List<AppInfo>> getInstalledPackages() async => [
        AppInfo(packageName: 'com.example.app', name: 'Example', isSystemApp: false),
        AppInfo(packageName: 'com.android.system', name: 'System', isSystemApp: true),
      ];

  @override
  Future<String?> getPackageIcon(String packageName) async => 'base64data';

  @override
  Future<int> urlTest(String link, {int timeout = 5000}) async => 120;

  @override
  Future<Map<String, int>> urlTestAll(List<String> links,
      {int timeout = 5000}) async {
    return {for (var l in links) l: 100};
  }

  @override
  Future<bool> setPerAppProxyMode(PerAppProxyMode mode) async {
    _perAppMode = mode;
    return true;
  }

  @override
  Future<PerAppProxyMode> getPerAppProxyMode() async => _perAppMode;

  @override
  Future<bool> setPerAppProxyList(
      List<String> packages, PerAppProxyMode mode) async {
    if (mode == PerAppProxyMode.include) {
      _includeList = packages;
    } else {
      _excludeList = packages;
    }
    return true;
  }

  @override
  Future<List<String>> getPerAppProxyList(PerAppProxyMode mode) async {
    return mode == PerAppProxyMode.include ? _includeList : _excludeList;
  }

  @override
  Stream<VpnStatus> watchStatus() =>
      Stream.fromIterable([VpnStatus.stopped, VpnStatus.starting, VpnStatus.started]);

  @override
  Stream<VpnStats> watchStats() =>
      Stream.value(const VpnStats(uplink: 1024, downlink: 2048));

  @override
  Stream<Map<String, dynamic>> watchAlerts() => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> watchPingResults() =>
      Stream.value({'link': 'vless://test', 'latency': 80});

  @override
  Future<Map<String, int>> getTotalTraffic() async =>
      {'upload': 1000000, 'download': 5000000};

  @override
  Future<bool> resetTotalTraffic() async => true;

  @override
  Future<Map<String, dynamic>> getCoreInfo() async =>
      {'core': _coreEngine, 'engine': _coreEngine == 'xray' ? 'xray-core' : 'sing-box', 'version': '1.0.0'};

  @override
  Future<bool> setCoreEngine(String engine) async {
    _coreEngine = engine;
    return true;
  }

  @override
  Future<String> getCoreEngine() async => _coreEngine;

  @override
  Future<String> checkConfigJson(String configJson) async => '';

  @override
  Future<bool> startWithJson(String configJson, String name) async => true;

  @override
  Future<List<String>> getLogs() async => ['log line 1', 'log line 2'];

  @override
  Future<bool> clearLogs() async => true;

  @override
  Stream<Map<String, dynamic>> watchLogs() =>
      Stream.value({'message': 'test log'});

  @override
  Future<bool> setDebugMode(bool enabled) async {
    _debugMode = enabled;
    return true;
  }

  @override
  Future<bool> getDebugMode() async => _debugMode;

  @override
  Future<String> formatBytes(int bytes) async => '1.0 KB';

  @override
  Future<String> getActiveConfig() async => '{"outbounds":[]}';

  @override
  Future<String> proxyDisplayType(String type) async {
    switch (type) {
      case 'vmess': return 'VMess';
      case 'vless': return 'VLESS';
      default: return type;
    }
  }

  @override
  Future<String> formatConfig(String configJson) async => configJson;

  @override
  Future<int> availablePort(int startPort) async => startPort;

  @override
  Future<bool> selectOutbound(String groupTag, String outboundTag) async => true;

  @override
  Future<bool> setClashMode(String mode) async => true;

  @override
  Future<Map<String, dynamic>> parseSubscription(String link) async =>
      {'name': 'Test', 'url': 'https://example.com'};

  @override
  Future<String> generateSubscriptionLink(String name, String url) async =>
      'sub://test';

  @override
  Future<bool> setLocale(String locale) async {
    _locale = locale;
    return true;
  }

  @override
  Future<bool> setPingTestUrl(String url) async {
    _pingTestUrl = url;
    return true;
  }

  @override
  Future<String> getPingTestUrl() async => _pingTestUrl;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final V2rayBoxPlatform initialPlatform = V2rayBoxPlatform.instance;

  test('MethodChannelV2rayBox is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelV2rayBox>());
  });

  group('V2rayBox with MockPlatform', () {
    late V2rayBox v2ray;
    late MockV2rayBoxPlatform mock;

    setUp(() {
      mock = MockV2rayBoxPlatform();
      V2rayBoxPlatform.instance = mock;
      v2ray = V2rayBox();
    });

    test('getPlatformVersion returns platform string', () async {
      expect(await v2ray.getPlatformVersion(), 'Android 14');
    });

    group('Connection', () {
      test('connect returns true', () async {
        final result = await v2ray.connect('vless://test@server:443', name: 'Test');
        expect(result, isTrue);
      });

      test('disconnect returns true', () async {
        expect(await v2ray.disconnect(), isTrue);
      });

      test('restart returns true', () async {
        expect(await v2ray.restart('vless://test@server:443', name: 'Test'), isTrue);
      });

      test('connectWithJson returns true', () async {
        expect(await v2ray.connectWithJson('{"outbounds":[]}', name: 'Test'), isTrue);
      });
    });

    group('Core Engine', () {
      test('default core engine is xray', () async {
        expect(await v2ray.getCoreEngine(), 'xray');
      });

      test('setCoreEngine changes the engine', () async {
        await v2ray.setCoreEngine('singbox');
        expect(await v2ray.getCoreEngine(), 'singbox');
      });

      test('getCoreInfo returns engine info', () async {
        final info = await v2ray.getCoreInfo();
        expect(info['core'], 'xray');
        expect(info['engine'], 'xray-core');
        expect(info.containsKey('version'), isTrue);
      });

      test('getCoreInfo reflects engine change', () async {
        await v2ray.setCoreEngine('singbox');
        final info = await v2ray.getCoreInfo();
        expect(info['core'], 'singbox');
        expect(info['engine'], 'sing-box');
      });
    });

    group('VPN Mode', () {
      test('default service mode is vpn', () async {
        expect(await v2ray.getServiceMode(), VpnMode.vpn);
      });

      test('setServiceMode changes mode', () async {
        await v2ray.setServiceMode(VpnMode.proxy);
        expect(await v2ray.getServiceMode(), VpnMode.proxy);
      });
    });

    group('VPN Permission', () {
      test('checkVpnPermission returns true', () async {
        expect(await v2ray.checkVpnPermission(), isTrue);
      });

      test('requestVpnPermission returns true', () async {
        expect(await v2ray.requestVpnPermission(), isTrue);
      });
    });

    group('Ping', () {
      test('ping returns latency in ms', () async {
        expect(await v2ray.ping('vless://test'), 120);
      });

      test('pingAll returns map of latencies', () async {
        final links = ['vless://a', 'vmess://b'];
        final results = await v2ray.pingAll(links);
        expect(results.length, 2);
        expect(results['vless://a'], 100);
        expect(results['vmess://b'], 100);
      });

      test('setPingTestUrl and getPingTestUrl', () async {
        await v2ray.setPingTestUrl('https://example.com/test');
        expect(await v2ray.getPingTestUrl(), 'https://example.com/test');
      });
    });

    group('Per-App Proxy', () {
      test('default per-app proxy mode is off', () async {
        expect(await v2ray.getPerAppProxyMode(), PerAppProxyMode.off);
      });

      test('setPerAppProxyMode changes mode', () async {
        await v2ray.setPerAppProxyMode(PerAppProxyMode.exclude);
        expect(await v2ray.getPerAppProxyMode(), PerAppProxyMode.exclude);
      });

      test('setPerAppProxyList and getPerAppProxyList', () async {
        final packages = ['com.app1', 'com.app2'];
        await v2ray.setPerAppProxyList(packages, PerAppProxyMode.exclude);
        final result = await v2ray.getPerAppProxyList(PerAppProxyMode.exclude);
        expect(result, packages);
      });

      test('getInstalledApps returns app list', () async {
        final apps = await v2ray.getInstalledApps();
        expect(apps.length, 2);
        expect(apps[0].packageName, 'com.example.app');
        expect(apps[1].isSystemApp, isTrue);
      });

      test('getAppIcon returns base64', () async {
        expect(await v2ray.getAppIcon('com.example.app'), 'base64data');
      });
    });

    group('Traffic', () {
      test('getTotalTraffic returns upload and download', () async {
        final traffic = await v2ray.getTotalTraffic();
        expect(traffic.upload, 1000000);
        expect(traffic.download, 5000000);
        expect(traffic.total, 6000000);
      });

      test('resetTotalTraffic returns true', () async {
        expect(await v2ray.resetTotalTraffic(), isTrue);
      });
    });

    group('Streams', () {
      test('watchStatus emits status values', () async {
        final statuses = await v2ray.watchStatus().toList();
        expect(statuses, [VpnStatus.stopped, VpnStatus.starting, VpnStatus.started]);
      });

      test('watchStats emits traffic stats', () async {
        final stats = await v2ray.watchStats().first;
        expect(stats.uplink, 1024);
        expect(stats.downlink, 2048);
      });

      test('watchPingResults emits results', () async {
        final result = await v2ray.watchPingResults().first;
        expect(result['link'], 'vless://test');
        expect(result['latency'], 80);
      });
    });

    group('Config Utilities', () {
      test('parseConfig returns empty for valid config', () async {
        expect(await v2ray.parseConfig('vless://test'), '');
      });

      test('generateConfig returns JSON', () async {
        final config = await v2ray.generateConfig('vless://test');
        expect(config.contains('outbounds'), isTrue);
      });

      test('checkConfigJson returns empty for valid JSON', () async {
        expect(await v2ray.checkConfigJson('{}'), '');
      });

      test('getActiveConfig returns JSON', () async {
        final config = await v2ray.getActiveConfig();
        expect(config.isNotEmpty, isTrue);
      });
    });

    group('Logs & Debug', () {
      test('getLogs returns log lines', () async {
        final logs = await v2ray.getLogs();
        expect(logs.length, 2);
      });

      test('setDebugMode and getDebugMode', () async {
        await v2ray.setDebugMode(true);
        expect(await v2ray.getDebugMode(), isTrue);
        await v2ray.setDebugMode(false);
        expect(await v2ray.getDebugMode(), isFalse);
      });
    });

    group('Notification', () {
      test('setNotificationStopButtonText returns true', () async {
        expect(await v2ray.setNotificationStopButtonText('Disconnect'), isTrue);
      });

      test('setNotificationTitle returns true', () async {
        expect(await v2ray.setNotificationTitle('VPN Active'), isTrue);
      });

      test('setNotificationIcon returns true', () async {
        expect(await v2ray.setNotificationIcon('ic_vpn'), isTrue);
      });
    });

    group('Subscription', () {
      test('parseSubscription returns name and url', () async {
        final result = await v2ray.parseSubscription('sub://test');
        expect(result['name'], 'Test');
        expect(result['url'], 'https://example.com');
      });

      test('generateSubscriptionLink returns link', () async {
        final link = await v2ray.generateSubscriptionLink('Test', 'https://example.com');
        expect(link.isNotEmpty, isTrue);
      });
    });

    group('Misc', () {
      test('availablePort returns port number', () async {
        expect(await v2ray.availablePort(startPort: 2080), 2080);
      });

      test('selectOutbound returns true', () async {
        expect(await v2ray.selectOutbound('group', 'outbound'), isTrue);
      });

      test('setClashMode returns true', () async {
        expect(await v2ray.setClashMode('rule'), isTrue);
      });

      test('setLocale returns true', () async {
        expect(await v2ray.setLocale('fa'), isTrue);
      });

      test('proxyDisplayType returns display name', () async {
        expect(await v2ray.proxyDisplayType('vmess'), 'VMess');
        expect(await v2ray.proxyDisplayType('vless'), 'VLESS');
      });
    });
  });
}
