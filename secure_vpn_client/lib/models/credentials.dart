/// Per-session SOCKS5 credentials. Never persist or log these values.
class SessionCredentials {
  SessionCredentials({
    required String username,
    required String password,
  })  : _username = username,
        _password = password;

  String _username;
  String _password;

  String get username => _username;
  String get password => _password;

  bool get isCleared => _username.isEmpty && _password.isEmpty;

  void clear() {
    _username = '';
    _password = '';
  }

  @override
  String toString() => 'SessionCredentials(cleared: $isCleared)';
}
