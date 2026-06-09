enum VpnEngine {
  xray('xray'),
  singbox('singbox');

  const VpnEngine(this.coreName);

  final String coreName;

  static VpnEngine fromCoreName(String value) {
    switch (value.toLowerCase()) {
      case 'singbox':
        return VpnEngine.singbox;
      case 'xray':
      default:
        return VpnEngine.xray;
    }
  }
}
