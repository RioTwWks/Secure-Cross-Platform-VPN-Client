import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_box/v2ray_box.dart';

void main() {
  group('VpnStatus', () {
    test('fromString parses all values', () {
      expect(VpnStatus.fromString('stopped'), VpnStatus.stopped);
      expect(VpnStatus.fromString('starting'), VpnStatus.starting);
      expect(VpnStatus.fromString('started'), VpnStatus.started);
      expect(VpnStatus.fromString('stopping'), VpnStatus.stopping);
    });

    test('fromString is case-insensitive', () {
      expect(VpnStatus.fromString('STOPPED'), VpnStatus.stopped);
      expect(VpnStatus.fromString('Started'), VpnStatus.started);
    });

    test('fromString defaults to stopped for unknown', () {
      expect(VpnStatus.fromString('unknown'), VpnStatus.stopped);
      expect(VpnStatus.fromString(null), VpnStatus.stopped);
      expect(VpnStatus.fromString(''), VpnStatus.stopped);
    });
  });

  group('VpnMode', () {
    test('fromString parses all values', () {
      expect(VpnMode.fromString('vpn'), VpnMode.vpn);
      expect(VpnMode.fromString('proxy'), VpnMode.proxy);
    });

    test('fromString defaults to vpn for unknown', () {
      expect(VpnMode.fromString('unknown'), VpnMode.vpn);
      expect(VpnMode.fromString(null), VpnMode.vpn);
    });

    test('value returns name', () {
      expect(VpnMode.vpn.value, 'vpn');
      expect(VpnMode.proxy.value, 'proxy');
    });
  });

  group('PerAppProxyMode', () {
    test('fromString parses all values', () {
      expect(PerAppProxyMode.fromString('off'), PerAppProxyMode.off);
      expect(PerAppProxyMode.fromString('include'), PerAppProxyMode.include);
      expect(PerAppProxyMode.fromString('exclude'), PerAppProxyMode.exclude);
    });

    test('fromString defaults to off for unknown', () {
      expect(PerAppProxyMode.fromString('unknown'), PerAppProxyMode.off);
      expect(PerAppProxyMode.fromString(null), PerAppProxyMode.off);
    });

    test('value returns name', () {
      expect(PerAppProxyMode.off.value, 'off');
      expect(PerAppProxyMode.include.value, 'include');
      expect(PerAppProxyMode.exclude.value, 'exclude');
    });
  });

  group('VpnStats', () {
    test('default constructor has zero values', () {
      const stats = VpnStats();
      expect(stats.uplink, 0);
      expect(stats.downlink, 0);
      expect(stats.uplinkTotal, 0);
      expect(stats.downlinkTotal, 0);
      expect(stats.connectionsIn, 0);
      expect(stats.connectionsOut, 0);
    });

    test('fromJson parses correctly', () {
      final stats = VpnStats.fromJson({
        'connections-in': 5,
        'connections-out': 10,
        'uplink': 1024,
        'downlink': 2048,
        'uplink-total': 100000,
        'downlink-total': 500000,
      });
      expect(stats.connectionsIn, 5);
      expect(stats.connectionsOut, 10);
      expect(stats.uplink, 1024);
      expect(stats.downlink, 2048);
      expect(stats.uplinkTotal, 100000);
      expect(stats.downlinkTotal, 500000);
    });

    test('fromJson handles missing values', () {
      final stats = VpnStats.fromJson({});
      expect(stats.uplink, 0);
      expect(stats.downlink, 0);
    });

    test('fromJson handles null values', () {
      final stats = VpnStats.fromJson({
        'uplink': null,
        'downlink': null,
      });
      expect(stats.uplink, 0);
      expect(stats.downlink, 0);
    });

    test('formatBytes formats correctly', () {
      expect(VpnStats.formatBytes(0), '0 B');
      expect(VpnStats.formatBytes(512), '512 B');
      expect(VpnStats.formatBytes(1024), '1.0 KB');
      expect(VpnStats.formatBytes(1536), '1.5 KB');
      expect(VpnStats.formatBytes(1048576), '1.0 MB');
      expect(VpnStats.formatBytes(1073741824), '1.00 GB');
    });

    test('formattedUplink appends /s', () {
      const stats = VpnStats(uplink: 1024);
      expect(stats.formattedUplink, '1.0 KB/s');
    });

    test('formattedDownlink appends /s', () {
      const stats = VpnStats(downlink: 2048);
      expect(stats.formattedDownlink, '2.0 KB/s');
    });

    test('formattedUplinkTotal does not append /s', () {
      const stats = VpnStats(uplinkTotal: 1048576);
      expect(stats.formattedUplinkTotal, '1.0 MB');
    });

    test('toString contains formatted values', () {
      const stats = VpnStats(uplink: 1024, downlink: 2048);
      final str = stats.toString();
      expect(str.contains('1.0 KB/s'), isTrue);
      expect(str.contains('2.0 KB/s'), isTrue);
    });
  });

  group('VpnConfig', () {
    test('fromLink parses vless link', () {
      final config = VpnConfig.fromLink('vless://uuid@server.com:443?security=tls#MyVPN');
      expect(config.protocol, 'vless');
      expect(config.server, 'server.com');
      expect(config.port, 443);
      expect(config.name, 'MyVPN');
      expect(config.link, 'vless://uuid@server.com:443?security=tls#MyVPN');
    });

    test('fromLink parses trojan link', () {
      final config = VpnConfig.fromLink('trojan://pass@host:8443#Test');
      expect(config.protocol, 'trojan');
      expect(config.server, 'host');
      expect(config.port, 8443);
      expect(config.name, 'Test');
    });

    test('fromLink uses server as name when no fragment', () {
      final config = VpnConfig.fromLink('vless://uuid@myserver.com:443');
      expect(config.name, 'myserver.com');
    });

    test('fromLink handles invalid link gracefully', () {
      final config = VpnConfig.fromLink('not a valid link at all');
      expect(config.link, 'not a valid link at all');
      expect(config.id.isNotEmpty, isTrue);
    });

    test('isValidLink returns true for valid protocols', () {
      expect(VpnConfig.isValidLink('vless://test'), isTrue);
      expect(VpnConfig.isValidLink('vmess://test'), isTrue);
      expect(VpnConfig.isValidLink('trojan://test'), isTrue);
      expect(VpnConfig.isValidLink('ss://test'), isTrue);
      expect(VpnConfig.isValidLink('hysteria://test'), isTrue);
      expect(VpnConfig.isValidLink('hysteria2://test'), isTrue);
      expect(VpnConfig.isValidLink('tuic://test'), isTrue);
      expect(VpnConfig.isValidLink('wireguard://test'), isTrue);
    });

    test('isValidLink returns false for invalid protocols', () {
      expect(VpnConfig.isValidLink('http://test'), isFalse);
      expect(VpnConfig.isValidLink('invalid'), isFalse);
      expect(VpnConfig.isValidLink(''), isFalse);
    });

    test('protocolDisplayName returns correct names', () {
      expect(VpnConfig.fromLink('vmess://t').protocolDisplayName, 'VMess');
      expect(VpnConfig.fromLink('vless://t').protocolDisplayName, 'VLESS');
      expect(VpnConfig.fromLink('trojan://t').protocolDisplayName, 'Trojan');
      expect(VpnConfig.fromLink('ss://t').protocolDisplayName, 'Shadowsocks');
      expect(VpnConfig.fromLink('hysteria2://t').protocolDisplayName, 'Hysteria 2');
      expect(VpnConfig.fromLink('tuic://t').protocolDisplayName, 'TUIC');
    });

    test('pingDisplay formats correctly', () {
      final config = VpnConfig.fromLink('vless://t');
      expect(config.pingDisplay, '-');

      config.ping = 120;
      expect(config.pingDisplay, '120ms');

      config.ping = 10000;
      expect(config.pingDisplay, 'Timeout');
    });

    test('copyWith creates modified copy', () {
      final config = VpnConfig.fromLink('vless://uuid@server:443#Name');
      final copy = config.copyWith(name: 'New Name', ping: 100);
      expect(copy.name, 'New Name');
      expect(copy.ping, 100);
      expect(copy.server, config.server);
      expect(copy.protocol, config.protocol);
    });

    test('toJson and fromJson roundtrip', () {
      final config = VpnConfig(
        id: '1',
        link: 'vless://test',
        name: 'Test',
        protocol: 'vless',
        server: 'server.com',
        port: 443,
        ping: 50,
        isSelected: true,
      );
      final json = config.toJson();
      final restored = VpnConfig.fromJson(json);
      expect(restored.id, config.id);
      expect(restored.link, config.link);
      expect(restored.name, config.name);
      expect(restored.protocol, config.protocol);
      expect(restored.server, config.server);
      expect(restored.port, config.port);
      expect(restored.ping, config.ping);
      expect(restored.isSelected, config.isSelected);
    });
  });

  group('TotalTraffic', () {
    test('default constructor has zero values', () {
      const traffic = TotalTraffic();
      expect(traffic.upload, 0);
      expect(traffic.download, 0);
      expect(traffic.total, 0);
    });

    test('total is sum of upload and download', () {
      const traffic = TotalTraffic(upload: 100, download: 200);
      expect(traffic.total, 300);
    });

    test('fromJson parses correctly', () {
      final traffic = TotalTraffic.fromJson({'upload': 5000, 'download': 10000});
      expect(traffic.upload, 5000);
      expect(traffic.download, 10000);
    });

    test('fromJson handles missing values', () {
      final traffic = TotalTraffic.fromJson({});
      expect(traffic.upload, 0);
      expect(traffic.download, 0);
    });

    test('formatBytes formats correctly', () {
      expect(TotalTraffic.formatBytes(0), '0 B');
      expect(TotalTraffic.formatBytes(1024), '1.0 KB');
      expect(TotalTraffic.formatBytes(1048576), '1.0 MB');
      expect(TotalTraffic.formatBytes(1073741824), '1.00 GB');
    });

    test('formatted getters return human-readable strings', () {
      const traffic = TotalTraffic(upload: 1048576, download: 2097152);
      expect(traffic.formattedUpload, '1.0 MB');
      expect(traffic.formattedDownload, '2.0 MB');
      expect(traffic.formattedTotal, '3.0 MB');
    });

    test('toString contains formatted values', () {
      const traffic = TotalTraffic(upload: 1024, download: 2048);
      final str = traffic.toString();
      expect(str.contains('1.0 KB'), isTrue);
      expect(str.contains('2.0 KB'), isTrue);
    });
  });

  group('ConfigOptions', () {
    test('default values', () {
      const options = ConfigOptions();
      expect(options.blockAds, isFalse);
      expect(options.logLevel, 'warn');
      expect(options.mtu, 9000);
      expect(options.strictRoute, isTrue);
      expect(options.enableClashApi, isTrue);
      expect(options.enableTun, isTrue);
      expect(options.bypassLan, isTrue);
    });

    test('toJson produces correct keys', () {
      const options = ConfigOptions();
      final json = options.toJson();
      expect(json['block-ads'], isFalse);
      expect(json['log-level'], 'warn');
      expect(json['mtu'], 9000);
      expect(json['strict-route'], isTrue);
      expect(json['enable-clash-api'], isTrue);
      expect(json['enable-tun'], isTrue);
      expect(json['mixed-port'], 2080);
    });

    test('toJsonString returns valid JSON string', () {
      const options = ConfigOptions();
      final jsonStr = options.toJsonString();
      expect(jsonStr.isNotEmpty, isTrue);
      expect(jsonStr.startsWith('{'), isTrue);
    });

    test('fromJson restores values', () {
      final options = ConfigOptions.fromJson({
        'block-ads': true,
        'log-level': 'info',
        'mtu': 1500,
        'mixed-port': 3000,
        'enable-tun': false,
      });
      expect(options.blockAds, isTrue);
      expect(options.logLevel, 'info');
      expect(options.mtu, 1500);
      expect(options.mixedPort, 3000);
      expect(options.enableTun, isFalse);
    });

    test('fromJson uses defaults for missing keys', () {
      final options = ConfigOptions.fromJson({});
      expect(options.blockAds, isFalse);
      expect(options.logLevel, 'warn');
      expect(options.mtu, 9000);
    });
  });

  group('AppInfo', () {
    test('fromJson parses correctly', () {
      final app = AppInfo.fromJson({
        'package-name': 'com.example.app',
        'name': 'Example App',
        'is-system-app': false,
      });
      expect(app.packageName, 'com.example.app');
      expect(app.name, 'Example App');
      expect(app.isSystemApp, isFalse);
    });

    test('fromJson defaults isSystemApp to false', () {
      final app = AppInfo.fromJson({
        'package-name': 'com.test',
        'name': 'Test',
      });
      expect(app.isSystemApp, isFalse);
    });

    test('toJson produces correct keys', () {
      final app = AppInfo(packageName: 'com.test', name: 'Test', isSystemApp: true);
      final json = app.toJson();
      expect(json['package-name'], 'com.test');
      expect(json['name'], 'Test');
      expect(json['is-system-app'], isTrue);
    });

    test('toString contains package name', () {
      final app = AppInfo(packageName: 'com.test', name: 'Test', isSystemApp: false);
      expect(app.toString().contains('com.test'), isTrue);
    });
  });
}
