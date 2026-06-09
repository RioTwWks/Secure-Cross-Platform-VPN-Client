import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/utils/config_parser.dart';
import 'package:secure_vpn_client/utils/link_config_builder.dart';

void main() {
  group('LinkConfigBuilder', () {
    test('builds Xray config from vless link', () {
      const link =
          'vless://11111111-2222-3333-4444-555555555555@example.com:443?security=tls&sni=example.com&type=ws&path=/ws#test';
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.xray);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final outbounds = decoded['outbounds'] as List<dynamic>;
      expect(outbounds.first['protocol'], 'vless');
    });

    test('builds sing-box config from trojan link', () {
      const link = 'trojan://secret@example.com:443?security=tls&sni=example.com';
      final json = LinkConfigBuilder.buildFromLink(link, VpnEngine.singbox);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final outbounds = decoded['outbounds'] as List<dynamic>;
      expect(outbounds.first['type'], 'trojan');
    });
  });

  group('ConfigParser subscription', () {
    test('extracts first config link from base64 subscription', () {
      const body = 'dmxlc3M6Ly9hYmNkQGV4YW1wbGUuY29tOjQ0Mw==';
      final normalized = ConfigParser.normalizeSubscriptionContent(body);
      expect(normalized.startsWith('vless://'), isTrue);
    });
  });
}
