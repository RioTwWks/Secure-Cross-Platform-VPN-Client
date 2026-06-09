/// Represents a VPN configuration/profile
class VpnConfig {
  /// Unique identifier for the config
  final String id;

  /// Raw config link (vmess://, vless://, etc.)
  final String link;

  /// Display name extracted from the link or user-defined
  final String name;

  /// Protocol type (vmess, vless, trojan, etc.)
  final String protocol;

  /// Server address
  final String? server;

  /// Server port
  final int? port;

  /// Ping latency in milliseconds, -1 if not tested or failed
  int ping;

  /// Whether this config is currently selected
  bool isSelected;

  VpnConfig({
    required this.id,
    required this.link,
    required this.name,
    required this.protocol,
    this.server,
    this.port,
    this.ping = -1,
    this.isSelected = false,
  });

  /// Parse a config link and create a VpnConfig object
  factory VpnConfig.fromLink(String link) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    String protocol = '';
    String name = '';
    String? server;
    int? port;

    try {
      final uri = Uri.parse(link);
      protocol = uri.scheme;

      // Extract name from fragment
      if (uri.hasFragment) {
        name = Uri.decodeComponent(uri.fragment);
      }

      // Try to extract server and port
      if (uri.host.isNotEmpty) {
        server = uri.host;
        port = uri.port > 0 ? uri.port : null;
      }

      // If name is empty, use server as name
      if (name.isEmpty && server != null) {
        name = server;
      }
    } catch (e) {
      // If parsing fails, try to extract basic info
      if (link.contains('://')) {
        protocol = link.split('://').first;
      }
      name = 'Unknown Config';
    }

    return VpnConfig(
      id: id,
      link: link,
      name: name,
      protocol: protocol,
      server: server,
      port: port,
    );
  }

  /// Check if this is a valid V2Ray config link
  static bool isValidLink(String link) {
    final validProtocols = [
      'vmess',
      'vless',
      'trojan',
      'ss',
      'ssr',
      'hy',
      'hy2',
      'hysteria',
      'hysteria2',
      'tuic',
      'wg',
      'wireguard',
      'ssh',
    ];

    try {
      final uri = Uri.parse(link);
      return validProtocols.contains(uri.scheme.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  /// Get protocol display name
  String get protocolDisplayName {
    switch (protocol.toLowerCase()) {
      case 'vmess':
        return 'VMess';
      case 'vless':
        return 'VLESS';
      case 'trojan':
        return 'Trojan';
      case 'ss':
        return 'Shadowsocks';
      case 'ssr':
        return 'ShadowsocksR';
      case 'hysteria':
      case 'hy':
        return 'Hysteria';
      case 'hysteria2':
      case 'hy2':
        return 'Hysteria 2';
      case 'tuic':
        return 'TUIC';
      case 'wireguard':
      case 'wg':
        return 'WireGuard';
      case 'ssh':
        return 'SSH';
      default:
        return protocol.toUpperCase();
    }
  }

  /// Get formatted ping display
  String get pingDisplay {
    if (ping < 0) return '-';
    if (ping > 9999) return 'Timeout';
    return '${ping}ms';
  }

  VpnConfig copyWith({
    String? id,
    String? link,
    String? name,
    String? protocol,
    String? server,
    int? port,
    int? ping,
    bool? isSelected,
  }) {
    return VpnConfig(
      id: id ?? this.id,
      link: link ?? this.link,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      server: server ?? this.server,
      port: port ?? this.port,
      ping: ping ?? this.ping,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'link': link,
      'name': name,
      'protocol': protocol,
      'server': server,
      'port': port,
      'ping': ping,
      'isSelected': isSelected,
    };
  }

  factory VpnConfig.fromJson(Map<String, dynamic> json) {
    return VpnConfig(
      id: json['id'] as String,
      link: json['link'] as String,
      name: json['name'] as String,
      protocol: json['protocol'] as String,
      server: json['server'] as String?,
      port: json['port'] as int?,
      ping: json['ping'] as int? ?? -1,
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }
}
