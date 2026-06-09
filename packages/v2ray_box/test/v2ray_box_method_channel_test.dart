import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_box/v2ray_box.dart';
import 'package:v2ray_box/v2ray_box_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelV2rayBox();
  const channel = MethodChannel('v2ray_box');

  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'getPlatformVersion':
          return 'Android 14';
        case 'setup':
          return null;
        case 'parse_config':
          return '';
        case 'change_config_options':
          return true;
        case 'generate_config':
          return '{"outbounds":[]}';
        case 'start':
          return true;
        case 'stop':
          return true;
        case 'restart':
          return true;
        case 'check_vpn_permission':
          return true;
        case 'request_vpn_permission':
          return true;
        case 'set_service_mode':
          return true;
        case 'get_service_mode':
          return 'vpn';
        case 'set_notification_stop_button_text':
          return true;
        case 'set_notification_title':
          return true;
        case 'set_notification_icon':
          return true;
        case 'get_installed_packages':
          return '[{"package-name":"com.test","name":"Test","is-system-app":false}]';
        case 'get_package_icon':
          return 'icondata';
        case 'url_test':
          return 150;
        case 'url_test_all':
          return {'vless://a': 100};
        case 'set_per_app_proxy_mode':
          return true;
        case 'get_per_app_proxy_mode':
          return 'off';
        case 'set_per_app_proxy_list':
          return true;
        case 'get_per_app_proxy_list':
          return <String>['com.app'];
        case 'get_total_traffic':
          return {'upload': 500, 'download': 1000};
        case 'reset_total_traffic':
          return true;
        case 'get_core_info':
          return {'core': 'xray', 'engine': 'xray-core', 'version': '26.2.6'};
        case 'set_core_engine':
          return true;
        case 'get_core_engine':
          return 'xray';
        case 'check_config_json':
          return '';
        case 'start_with_json':
          return true;
        case 'get_logs':
          return <String>['line1'];
        case 'set_debug_mode':
          return true;
        case 'get_debug_mode':
          return false;
        case 'format_bytes':
          return '1.5 MB';
        case 'get_active_config':
          return '{}';
        case 'proxy_display_type':
          return 'VMess';
        case 'format_config':
          return '{\n}';
        case 'available_port':
          return 2080;
        case 'select_outbound':
          return true;
        case 'set_clash_mode':
          return true;
        case 'parse_subscription':
          return {'name': 'Sub', 'url': 'https://sub.com'};
        case 'generate_subscription_link':
          return 'sub://link';
        case 'set_locale':
          return true;
        case 'set_ping_test_url':
          return true;
        case 'get_ping_test_url':
          return 'http://test.com';
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('MethodChannel basic calls', () {
    test('getPlatformVersion', () async {
      expect(await platform.getPlatformVersion(), 'Android 14');
    });

    test('setup', () async {
      await platform.setup();
      expect(log.any((c) => c.method == 'setup'), isTrue);
    });

    test('parseConfig', () async {
      final result = await platform.parseConfig('vless://test');
      expect(result, '');
      expect(log.last.arguments['link'], 'vless://test');
    });

    test('generateConfig', () async {
      final result = await platform.generateConfig('vless://test');
      expect(result.contains('outbounds'), isTrue);
    });

    test('start', () async {
      expect(await platform.start('vless://test', 'MyVPN'), isTrue);
      expect(log.last.arguments['link'], 'vless://test');
      expect(log.last.arguments['name'], 'MyVPN');
    });

    test('stop', () async {
      expect(await platform.stop(), isTrue);
    });

    test('restart', () async {
      expect(await platform.restart('vless://test', 'VPN'), isTrue);
    });
  });

  group('MethodChannel VPN permission', () {
    test('checkVpnPermission', () async {
      expect(await platform.checkVpnPermission(), isTrue);
    });

    test('requestVpnPermission', () async {
      expect(await platform.requestVpnPermission(), isTrue);
    });
  });

  group('MethodChannel service mode', () {
    test('setServiceMode sends correct mode', () async {
      await platform.setServiceMode(VpnMode.proxy);
      expect(log.last.arguments, 'proxy');
    });

    test('getServiceMode returns VpnMode', () async {
      expect(await platform.getServiceMode(), VpnMode.vpn);
    });
  });

  group('MethodChannel notifications', () {
    test('setNotificationStopButtonText', () async {
      expect(await platform.setNotificationStopButtonText('Disconnect'), isTrue);
      expect(log.last.arguments, 'Disconnect');
    });

    test('setNotificationTitle', () async {
      expect(await platform.setNotificationTitle('VPN'), isTrue);
    });

    test('setNotificationIcon', () async {
      expect(await platform.setNotificationIcon('ic_vpn'), isTrue);
    });
  });

  group('MethodChannel per-app proxy', () {
    test('setPerAppProxyMode', () async {
      expect(await platform.setPerAppProxyMode(PerAppProxyMode.exclude), isTrue);
    });

    test('getPerAppProxyMode', () async {
      expect(await platform.getPerAppProxyMode(), PerAppProxyMode.off);
    });

    test('getInstalledPackages', () async {
      final apps = await platform.getInstalledPackages();
      expect(apps.length, 1);
      expect(apps[0].packageName, 'com.test');
    });

    test('getPackageIcon', () async {
      expect(await platform.getPackageIcon('com.test'), 'icondata');
    });
  });

  group('MethodChannel ping', () {
    test('urlTest returns latency', () async {
      expect(await platform.urlTest('vless://test'), 150);
    });

    test('urlTestAll returns map', () async {
      final results = await platform.urlTestAll(['vless://a']);
      expect(results['vless://a'], 100);
    });

    test('setPingTestUrl', () async {
      expect(await platform.setPingTestUrl('http://test.com'), isTrue);
    });

    test('getPingTestUrl', () async {
      expect(await platform.getPingTestUrl(), 'http://test.com');
    });
  });

  group('MethodChannel traffic', () {
    test('getTotalTraffic', () async {
      final traffic = await platform.getTotalTraffic();
      expect(traffic['upload'], 500);
      expect(traffic['download'], 1000);
    });

    test('resetTotalTraffic', () async {
      expect(await platform.resetTotalTraffic(), isTrue);
    });
  });

  group('MethodChannel core engine', () {
    test('getCoreInfo', () async {
      final info = await platform.getCoreInfo();
      expect(info['core'], 'xray');
      expect(info['version'], '26.2.6');
    });

    test('setCoreEngine', () async {
      expect(await platform.setCoreEngine('singbox'), isTrue);
      expect(log.last.arguments, 'singbox');
    });

    test('getCoreEngine', () async {
      expect(await platform.getCoreEngine(), 'xray');
    });
  });

  group('MethodChannel config utilities', () {
    test('checkConfigJson', () async {
      expect(await platform.checkConfigJson('{}'), '');
    });

    test('startWithJson', () async {
      expect(await platform.startWithJson('{}', 'test'), isTrue);
    });

    test('getActiveConfig', () async {
      expect(await platform.getActiveConfig(), '{}');
    });

    test('formatConfig', () async {
      expect((await platform.formatConfig('{}')).isNotEmpty, isTrue);
    });

    test('proxyDisplayType', () async {
      expect(await platform.proxyDisplayType('vmess'), 'VMess');
    });
  });

  group('MethodChannel logs & debug', () {
    test('getLogs', () async {
      final logs = await platform.getLogs();
      expect(logs, ['line1']);
    });

    test('setDebugMode', () async {
      expect(await platform.setDebugMode(true), isTrue);
      expect(log.last.arguments, true);
    });

    test('getDebugMode', () async {
      expect(await platform.getDebugMode(), isFalse);
    });
  });

  group('MethodChannel misc', () {
    test('formatBytes', () async {
      expect(await platform.formatBytes(1500000), '1.5 MB');
    });

    test('availablePort', () async {
      expect(await platform.availablePort(2080), 2080);
    });

    test('selectOutbound', () async {
      expect(await platform.selectOutbound('group', 'proxy'), isTrue);
    });

    test('setClashMode', () async {
      expect(await platform.setClashMode('rule'), isTrue);
    });

    test('parseSubscription', () async {
      final result = await platform.parseSubscription('sub://test');
      expect(result['name'], 'Sub');
    });

    test('generateSubscriptionLink', () async {
      expect(await platform.generateSubscriptionLink('n', 'u'), 'sub://link');
    });

    test('setLocale', () async {
      expect(await platform.setLocale('fa'), isTrue);
    });
  });
}
