import '../models/credentials.dart';
import '../utils/crypto_utils.dart';

class CredentialService {
  static const int usernameLength = 12;
  static const int passwordLength = 24;

  SessionCredentials generate() {
    return SessionCredentials(
      username: generateSecureRandomString(usernameLength),
      password: generateSecureRandomString(passwordLength),
    );
  }

  void clear(SessionCredentials credentials) {
    credentials.clear();
  }
}
