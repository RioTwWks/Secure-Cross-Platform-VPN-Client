import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/credentials.dart';
import '../models/vpn_engine.dart';

class ConfigParserException implements Exception {
  ConfigParserException(this.message);

  final String message;

  @override
  String toString() => 'ConfigParserException: $message';
}

class ConfigParser {
  static const int defaultSocksPort = 1080;
  static const int vulnerablePort = 7890;

  static bool isSingboxConfig(Map<String, dynamic> config) {
    return config.containsKey('outbounds') &&
        config['outbounds'] is List &&
        (config['outbounds'] as List).isNotEmpty &&
        (config['outbounds'] as List).first is Map &&
        ((config['outbounds'] as List).first as Map).containsKey('type');
  }

  static Future<String> parseFromUrl(
    String url, {
    required VpnEngine engine,
  }) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': _subscriptionUserAgent(engine),
        'Accept-Encoding': 'identity',
      },
    );
    if (response.statusCode != 200) {
      throw ConfigParserException(
        'Failed to fetch subscription: HTTP ${response.statusCode}',
      );
    }

    return normalizeSubscriptionContent(response.body.trim());
  }

  /// Subscription panels return different formats depending on User-Agent.
  /// Dart's default UA often yields an app-specific JSON bundle (e.g. Hiddify)
  /// that is unsuitable for desktop proxy mode.
  static String _subscriptionUserAgent(VpnEngine engine) {
    return engine == VpnEngine.singbox ? 'sing-box' : 'v2rayNG/1.8.29';
  }

  /// Converts subscription body to either JSON config or a single config link.
  static String normalizeSubscriptionContent(String body) {
    var content = body;
    try {
      final decoded = utf8.decode(base64.decode(_padBase64(body)));
      if (decoded.trim().isNotEmpty) {
        content = decoded.trim();
      }
    } catch (_) {
      // Not base64 — use raw body.
    }

    final trimmed = content.trim();
    if (trimmed.startsWith('[')) {
      final decoded = jsonDecode(trimmed);
      if (decoded is List && decoded.isNotEmpty) {
        return jsonEncode(_selectV2rayNgConfig(decoded));
      }
      throw ConfigParserException('Subscription JSON array is empty');
    }

    if (trimmed.startsWith('{')) {
      return trimmed;
    }

    for (final line in content.split('\n')) {
      final lineTrimmed = line.trim();
      if (lineTrimmed.isEmpty || lineTrimmed.startsWith('#')) {
        continue;
      }
      if (_looksLikeConfigLink(lineTrimmed) && !_isDecoyLink(lineTrimmed)) {
        return lineTrimmed;
      }
    }

    throw ConfigParserException(
      'Subscription does not contain JSON config or supported config links',
    );
  }

  static Map<String, dynamic> _selectV2rayNgConfig(List<dynamic> configs) {
    for (final raw in configs) {
      if (raw is! Map) {
        continue;
      }
      final config = Map<String, dynamic>.from(raw);
      if (!_isDecoyXraySubscription(config)) {
        return config;
      }
    }
    throw ConfigParserException(
      'Subscription does not contain a valid Xray server config',
    );
  }

  static bool _isDecoyXraySubscription(Map<String, dynamic> config) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) {
      return true;
    }
    for (final raw in outbounds) {
      if (raw is! Map) {
        continue;
      }
      final protocol = raw['protocol']?.toString();
      if (protocol == 'vless' ||
          protocol == 'vmess' ||
          protocol == 'trojan' ||
          protocol == 'shadowsocks') {
        return false;
      }
    }
    return true;
  }

  static bool _isDecoyLink(String value) {
    final lower = value.toLowerCase();
    return lower.contains('fake_ip_for_sub_link') ||
        RegExp(r'20\.\d{2}--').hasMatch(lower);
  }

  static bool _looksLikeConfigLink(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('vless://') ||
        lower.startsWith('vmess://') ||
        lower.startsWith('trojan://') ||
        lower.startsWith('ss://');
  }

  static String _padBase64(String value) {
    final padding = value.length % 4;
    if (padding == 0) {
      return value;
    }
    return value + '=' * (4 - padding);
  }

  static String injectSecureSocksInbound(
    String jsonConfig,
    SessionCredentials credentials,
    VpnEngine engine, {
    int socksPort = defaultSocksPort,
    bool proxyOnly = false,
  }) {
    final decoded = jsonDecode(jsonConfig);
    if (decoded is! Map<String, dynamic>) {
      throw ConfigParserException('Config root must be a JSON object');
    }

    final config = Map<String, dynamic>.from(decoded);
    if (engine == VpnEngine.xray) {
      _normalizeXraySubscriptionConfig(config);
    }
    if (engine == VpnEngine.singbox) {
      _migrateSingboxLegacyDns(config);
    }
    _sanitizeInboundsForProxy(config, engine, proxyOnly: proxyOnly);
    _removeUnsafeSocksInbounds(config, engine);

    final inbound = engine == VpnEngine.singbox
        ? _buildSingboxSocksInbound(credentials, socksPort)
        : _buildXraySocksInbound(credentials, socksPort);

    final inbounds = <dynamic>[
      ...(config['inbounds'] as List<dynamic>? ?? const []),
      inbound,
    ];
    if (proxyOnly) {
      final httpPort = socksPort + 1;
      inbounds.add(
        engine == VpnEngine.singbox
            ? _buildSingboxHttpInbound(credentials, httpPort)
            : _buildXrayHttpInbound(credentials, httpPort),
      );
    }
    config['inbounds'] = inbounds;

    validateSecure(jsonEncode(config), engine: engine);
    return const JsonEncoder.withIndent('  ').convert(config);
  }

  static Map<String, dynamic> _buildXraySocksInbound(
    SessionCredentials credentials,
    int socksPort,
  ) {
    return {
      'tag': 'secure-socks-in',
      'listen': '127.0.0.1',
      'port': socksPort,
      'protocol': 'socks',
      'sniffing': {
        'enabled': true,
        'destOverride': ['http', 'tls'],
      },
      'settings': {
        'auth': 'password',
        'accounts': [
          {
            'user': credentials.username,
            'pass': credentials.password,
          },
        ],
        'udp': true,
      },
    };
  }

  static Map<String, dynamic> _buildXrayHttpInbound(
    SessionCredentials credentials,
    int httpPort,
  ) {
    return {
      'tag': 'secure-http-in',
      'listen': '127.0.0.1',
      'port': httpPort,
      'protocol': 'http',
      'settings': {
        'accounts': [
          {
            'user': credentials.username,
            'pass': credentials.password,
          },
        ],
      },
    };
  }

  static Map<String, dynamic> _buildSingboxHttpInbound(
    SessionCredentials credentials,
    int httpPort,
  ) {
    return {
      'type': 'http',
      'tag': 'secure-http-in',
      'listen': '127.0.0.1',
      'listen_port': httpPort,
      'users': [
        {
          'username': credentials.username,
          'password': credentials.password,
        },
      ],
    };
  }

  static Map<String, dynamic> _buildSingboxSocksInbound(
    SessionCredentials credentials,
    int socksPort,
  ) {
    return {
      'type': 'socks',
      'tag': 'secure-socks-in',
      'listen': '127.0.0.1',
      'listen_port': socksPort,
      'users': [
        {
          'username': credentials.username,
          'password': credentials.password,
        },
      ],
    };
  }

  static void _normalizeXraySubscriptionConfig(Map<String, dynamic> config) {
    final proxyTag = _primaryXrayOutboundTag(config);
    if (proxyTag == null) {
      return;
    }

    final routing = config['routing'];
    if (routing is! Map) {
      return;
    }
    final rules = routing['rules'];
    if (rules is! List) {
      return;
    }

    routing['rules'] = rules
        .map((rule) {
          if (rule is! Map) {
            return rule;
          }
          final normalized = Map<String, dynamic>.from(rule);
          final inboundTag = normalized['inboundTag'];
          if (inboundTag == 'api' ||
              (inboundTag is List && inboundTag.contains('api'))) {
            return null;
          }
          if (normalized['outboundTag'] == 'proxy') {
            normalized['outboundTag'] = proxyTag;
          }
          return normalized;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static String? _primaryXrayOutboundTag(Map<String, dynamic> config) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) {
      return null;
    }
    for (final raw in outbounds) {
      if (raw is! Map) {
        continue;
      }
      final protocol = raw['protocol']?.toString();
      if (protocol == 'vless' ||
          protocol == 'vmess' ||
          protocol == 'trojan' ||
          protocol == 'shadowsocks') {
        return raw['tag']?.toString();
      }
    }
    return null;
  }

  static void _sanitizeInboundsForProxy(
    Map<String, dynamic> config,
    VpnEngine engine, {
    bool proxyOnly = false,
  }) {
    final inbounds = config['inbounds'];
    if (inbounds is! List) {
      return;
    }

    final removedTags = <String>{};
    final kept = <dynamic>[];

    for (final raw in inbounds) {
      if (raw is! Map) {
        if (!proxyOnly) {
          kept.add(raw);
        }
        continue;
      }
      final inbound = Map<String, dynamic>.from(raw);
      final tag = inbound['tag']?.toString();
      if (proxyOnly) {
        if (tag != null && tag.isNotEmpty) {
          removedTags.add(tag);
        }
        continue;
      }
      final valid = engine == VpnEngine.singbox
          ? _isValidSingboxInboundForProxy(inbound)
          : _isValidXrayInboundForProxy(inbound);
      if (!valid) {
        if (tag != null && tag.isNotEmpty) {
          removedTags.add(tag);
        }
        continue;
      }
      kept.add(inbound);
    }

    config['inbounds'] = kept;
    if (removedTags.isNotEmpty) {
      _sanitizeRoutingForRemovedInbounds(config, engine, removedTags);
    }
  }

  static void _migrateSingboxLegacyDns(Map<String, dynamic> config) {
    final dns = config['dns'];
    if (dns is! Map) {
      return;
    }
    final servers = dns['servers'];
    if (servers is! List) {
      return;
    }

    final migrated = <Map<String, dynamic>>[];
    for (final raw in servers) {
      if (raw is String) {
        migrated.add({
          'type': raw == 'local' ? 'local' : 'udp',
          if (raw != 'local') 'server': raw,
          'tag': 'dns-${migrated.length}',
        });
        continue;
      }
      if (raw is! Map) {
        continue;
      }
      final server = Map<String, dynamic>.from(raw);
      if (server.containsKey('type')) {
        migrated.add(server);
        continue;
      }
      final address = server['address']?.toString();
      if (address == null || address.isEmpty) {
        continue;
      }
      final tag = server['tag']?.toString() ?? 'dns-${migrated.length}';
      final detour = server['detour'];
      final strategy = server['strategy'];
      final resolver = server['address_resolver'];

      Map<String, dynamic> migratedServer;
      if (address == 'local' || address == 'dhcp://') {
        migratedServer = {'type': 'local', 'tag': tag};
      } else if (address.startsWith('tcp://')) {
        migratedServer = {
          'type': 'tcp',
          'server': address.substring(6),
          'tag': tag,
        };
      } else if (address.startsWith('udp://')) {
        migratedServer = {
          'type': 'udp',
          'server': address.substring(6),
          'tag': tag,
        };
      } else if (address.startsWith('https://') ||
          address.startsWith('h3://') ||
          address.startsWith('quic://')) {
        migratedServer = {
          'type': 'https',
          'server': address,
          'tag': tag,
        };
      } else if (address.startsWith('rcode://')) {
        migratedServer = {'type': 'empty', 'tag': tag};
      } else {
        migratedServer = {'type': 'udp', 'server': address, 'tag': tag};
      }
      if (detour != null) {
        migratedServer['detour'] = detour;
      }
      if (strategy != null) {
        migratedServer['strategy'] = strategy;
      }
      if (resolver != null) {
        migratedServer['address_resolver'] = resolver;
      }
      migrated.add(migratedServer);
    }
    dns['servers'] = migrated;
  }

  static bool _isValidXrayInboundForProxy(Map<String, dynamic> inbound) {
    final protocol = inbound['protocol']?.toString();
    if (protocol == 'tun') {
      return false;
    }

    final port = inbound['port'];
    if (port == null) {
      return false;
    }
    return true;
  }

  static bool _isValidSingboxInboundForProxy(Map<String, dynamic> inbound) {
    final type = inbound['type']?.toString();
    if (type == 'tun' || type == 'mixed') {
      return false;
    }

    final port = inbound['listen_port'] ?? inbound['port'];
    if (port == null) {
      return false;
    }
    return true;
  }

  static void _sanitizeRoutingForRemovedInbounds(
    Map<String, dynamic> config,
    VpnEngine engine,
    Set<String> removedTags,
  ) {
    if (engine == VpnEngine.xray) {
      final routing = config['routing'];
      if (routing is! Map) {
        return;
      }
      final rules = routing['rules'];
      if (rules is! List) {
        return;
      }
      routing['rules'] = rules.where((rule) {
        if (rule is! Map) {
          return true;
        }
        final inboundTag = rule['inboundTag'];
        if (inboundTag is List) {
          return !inboundTag.any(
            (tag) => removedTags.contains(tag.toString()),
          );
        }
        if (inboundTag is String) {
          return !removedTags.contains(inboundTag);
        }
        return true;
      }).toList();
      return;
    }

    final route = config['route'];
    if (route is! Map) {
      return;
    }
    final rules = route['rules'];
    if (rules is! List) {
      return;
    }
    route['rules'] = rules.where((rule) {
      if (rule is! Map) {
        return true;
      }
      final inbound = rule['inbound'];
      if (inbound is List) {
        return !inbound.any((tag) => removedTags.contains(tag.toString()));
      }
      if (inbound is String) {
        return !removedTags.contains(inbound);
      }
      return true;
    }).toList();
  }

  static void _removeUnsafeSocksInbounds(
    Map<String, dynamic> config,
    VpnEngine engine,
  ) {
    final inbounds = config['inbounds'];
    if (inbounds is! List) {
      return;
    }

    config['inbounds'] = inbounds.where((raw) {
      if (raw is! Map) {
        return true;
      }
      final inbound = Map<String, dynamic>.from(raw);
      if (!_isSocksInbound(inbound, engine)) {
        return true;
      }
      return !_isUnsafeSocksInbound(inbound, engine);
    }).toList();
  }

  static bool _isSocksInbound(
    Map<String, dynamic> inbound,
    VpnEngine engine,
  ) {
    if (engine == VpnEngine.singbox) {
      return inbound['type'] == 'socks';
    }
    return inbound['protocol'] == 'socks';
  }

  static bool _isUnsafeSocksInbound(
    Map<String, dynamic> inbound,
    VpnEngine engine,
  ) {
    final listen = (inbound['listen'] ?? '127.0.0.1').toString();
    final port = engine == VpnEngine.singbox
        ? inbound['listen_port'] ?? inbound['port']
        : inbound['port'];

    if (listen == '0.0.0.0' || listen == '::' || listen == '::0') {
      return true;
    }
    if (port == vulnerablePort) {
      return true;
    }

    if (engine == VpnEngine.xray) {
      final settings = inbound['settings'];
      if (settings is Map) {
        final auth = settings['auth']?.toString();
        if (auth == null || auth == 'noauth') {
          return true;
        }
      } else {
        return true;
      }
    }

    if (engine == VpnEngine.singbox) {
      final users = inbound['users'];
      if (users is! List || users.isEmpty) {
        return true;
      }
    }

    return false;
  }

  static void validateSecure(
    String jsonConfig, {
    VpnEngine? engine,
  }) {
    final decoded = jsonDecode(jsonConfig);
    if (decoded is! Map<String, dynamic>) {
      throw ConfigParserException('Config root must be a JSON object');
    }

    final detectedEngine = engine ??
        (isSingboxConfig(decoded) ? VpnEngine.singbox : VpnEngine.xray);
    final inbounds = decoded['inbounds'];
    if (inbounds is! List || inbounds.isEmpty) {
      throw ConfigParserException('Config must contain at least one inbound');
    }

    final socksInbounds = inbounds
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((inbound) => _isSocksInbound(inbound, detectedEngine))
        .toList();

    if (socksInbounds.isEmpty) {
      throw ConfigParserException('Config must contain a SOCKS inbound');
    }

    for (final inbound in socksInbounds) {
      final listen = (inbound['listen'] ?? '127.0.0.1').toString();
      if (listen != '127.0.0.1') {
        throw ConfigParserException('SOCKS inbound must bind to 127.0.0.1');
      }

      final port = detectedEngine == VpnEngine.singbox
          ? inbound['listen_port'] ?? inbound['port']
          : inbound['port'];
      if (port == vulnerablePort) {
        throw ConfigParserException('Vulnerable port $vulnerablePort is not allowed');
      }

      if (detectedEngine == VpnEngine.xray) {
        final settings = inbound['settings'];
        if (settings is! Map || settings['auth'] != 'password') {
          throw ConfigParserException('Xray SOCKS inbound must use password auth');
        }
        final accounts = settings['accounts'];
        if (accounts is! List || accounts.isEmpty) {
          throw ConfigParserException('Xray SOCKS inbound requires accounts');
        }
      } else {
        final users = inbound['users'];
        if (users is! List || users.isEmpty) {
          throw ConfigParserException('sing-box SOCKS inbound requires users');
        }
      }
    }
  }
}
