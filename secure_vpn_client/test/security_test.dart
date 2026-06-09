import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/models/vpn_engine.dart';
import 'package:secure_vpn_client/services/credential_service.dart';
import 'package:secure_vpn_client/utils/config_parser.dart';

void main() {
  group('Security', () {
    test('credentials are not exposed in toString', () {
      final service = CredentialService();
      final credentials = service.generate();
      expect(credentials.toString(), isNot(contains(credentials.username)));
      expect(credentials.toString(), isNot(contains(credentials.password)));
    });

    test('parser removes vulnerable port 7890 inbounds', () {
      const config = '''
{
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 7890,
      "protocol": "socks",
      "settings": { "auth": "noauth" }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
''';
      final credentials = CredentialService().generate();
      final secure = ConfigParser.injectSecureSocksInbound(
        config,
        credentials,
        VpnEngine.xray,
      );
      final decoded = jsonDecode(secure) as Map<String, dynamic>;
      final ports = (decoded['inbounds'] as List)
          .map((item) => (item as Map)['port'])
          .toList();
      expect(ports, isNot(contains(ConfigParser.vulnerablePort)));
    });

    test('secure config always binds localhost', () {
      const config = '''
{
  "inbounds": [],
  "outbounds": [{ "protocol": "freedom" }]
}
''';
      final credentials = CredentialService().generate();
      final secure = ConfigParser.injectSecureSocksInbound(
        config,
        credentials,
        VpnEngine.xray,
      );
      final decoded = jsonDecode(secure) as Map<String, dynamic>;
      for (final inbound in decoded['inbounds'] as List) {
        expect((inbound as Map)['listen'], '127.0.0.1');
      }
    });
  });
}
