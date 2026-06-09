import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/services/credential_service.dart';
import 'package:secure_vpn_client/utils/crypto_utils.dart';

void main() {
  group('CredentialService', () {
    final service = CredentialService();

    test('generates expected credential lengths', () {
      final credentials = service.generate();
      expect(credentials.username.length, CredentialService.usernameLength);
      expect(credentials.password.length, CredentialService.passwordLength);
    });

    test('generates unique credentials', () {
      final values = <String>{};
      for (var i = 0; i < 100; i++) {
        final credentials = service.generate();
        values.add('${credentials.username}:${credentials.password}');
      }
      expect(values.length, 100);
    });

    test('uses secure charset', () {
      final credentials = service.generate();
      expect(isValidCredentialCharset(credentials.username), isTrue);
      expect(isValidCredentialCharset(credentials.password), isTrue);
    });

    test('clear wipes credential values', () {
      final credentials = service.generate();
      expect(credentials.isCleared, isFalse);
      service.clear(credentials);
      expect(credentials.isCleared, isTrue);
      expect(credentials.toString(), isNot(contains('password')));
    });
  });
}
