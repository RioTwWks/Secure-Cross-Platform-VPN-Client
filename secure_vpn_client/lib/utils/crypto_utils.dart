import 'dart:math';

const _charset = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// Generates a cryptographically secure random string.
String generateSecureRandomString(int length) {
  final random = Random.secure();
  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => _charset.codeUnitAt(random.nextInt(_charset.length)),
    ),
  );
}

bool isValidCredentialCharset(String value) {
  if (value.isEmpty) {
    return false;
  }
  final pattern = RegExp(r'^[a-z0-9]+$');
  return pattern.hasMatch(value);
}
