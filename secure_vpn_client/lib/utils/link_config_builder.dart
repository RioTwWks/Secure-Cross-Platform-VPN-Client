import 'dart:convert';

import '../models/vpn_engine.dart';
import 'config_parser.dart';

class LinkConfigBuilder {
  static bool isConfigLink(String value) {
    final lower = value.trim().toLowerCase();
    return lower.startsWith('vless://') ||
        lower.startsWith('vmess://') ||
        lower.startsWith('trojan://') ||
        lower.startsWith('ss://');
  }

  static String buildFromLink(String link, VpnEngine engine) {
    final normalized = link.trim();
    if (!isConfigLink(normalized)) {
      throw ConfigParserException('Unsupported config link format');
    }

    return engine == VpnEngine.singbox
        ? _buildSingbox(normalized)
        : _buildXray(normalized);
  }

  static String _buildXray(String link) {
    final outbound = _parseXrayOutbound(link);
    final config = {
      'log': {'loglevel': 'warning'},
      'inbounds': <dynamic>[],
      'outbounds': [
        outbound,
        {
          'tag': 'direct',
          'protocol': 'freedom',
        },
        {
          'tag': 'block',
          'protocol': 'blackhole',
        },
      ],
      'routing': {
        'domainStrategy': 'AsIs',
        'rules': <dynamic>[],
      },
    };
    return const JsonEncoder.withIndent('  ').convert(config);
  }

  static String _buildSingbox(String link) {
    final outbound = _parseSingboxOutbound(link);
    final config = {
      'log': {'level': 'warn'},
      'dns': {
        'servers': [
          {
            'type': 'local',
            'tag': 'dns-direct',
          },
        ],
      },
      'inbounds': <dynamic>[],
      'outbounds': [
        outbound,
        {
          'type': 'direct',
          'tag': 'direct',
        },
      ],
      'route': {
        'rules': <dynamic>[],
        'final': 'proxy',
      },
    };
    return const JsonEncoder.withIndent('  ').convert(config);
  }

  static Map<String, dynamic> _parseXrayOutbound(String link) {
    final lower = link.toLowerCase();
    if (lower.startsWith('vless://')) {
      return _parseXrayVless(link);
    }
    if (lower.startsWith('trojan://')) {
      return _parseXrayTrojan(link);
    }
    if (lower.startsWith('vmess://')) {
      return _parseXrayVmess(link);
    }
    if (lower.startsWith('ss://')) {
      return _parseXrayShadowsocks(link);
    }
    throw ConfigParserException('Unsupported Xray link');
  }

  static Map<String, dynamic> _parseSingboxOutbound(String link) {
    final lower = link.toLowerCase();
    if (lower.startsWith('vless://')) {
      return _parseSingboxVless(link);
    }
    if (lower.startsWith('trojan://')) {
      return _parseSingboxTrojan(link);
    }
    if (lower.startsWith('vmess://')) {
      return _parseSingboxVmess(link);
    }
    if (lower.startsWith('ss://')) {
      return _parseSingboxShadowsocks(link);
    }
    throw ConfigParserException('Unsupported sing-box link');
  }

  static Map<String, dynamic> _parseXrayVless(String link) {
    final uri = Uri.parse(link);
    final uuid = uri.userInfo;
    final server = uri.host;
    if (uuid.isEmpty || server.isEmpty) {
      throw ConfigParserException('Invalid vless link');
    }
    final port = uri.port > 0 ? uri.port : 443;
    final params = uri.queryParameters;

    final outbound = <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': server,
            'port': port,
            'users': [
              {
                'id': uuid,
                'encryption': params['encryption'] ?? 'none',
                if (params['flow']?.isNotEmpty == true) 'flow': params['flow'],
              },
            ],
          },
        ],
      },
      'streamSettings': _xrayStreamSettings(params, server),
    };
    return outbound;
  }

  static Map<String, dynamic> _parseXrayTrojan(String link) {
    final uri = Uri.parse(link);
    final password = uri.userInfo;
    final server = uri.host;
    if (password.isEmpty || server.isEmpty) {
      throw ConfigParserException('Invalid trojan link');
    }
    final port = uri.port > 0 ? uri.port : 443;
    return {
      'tag': 'proxy',
      'protocol': 'trojan',
      'settings': {
        'servers': [
          {
            'address': server,
            'port': port,
            'password': password,
          },
        ],
      },
      'streamSettings': _xrayStreamSettings(uri.queryParameters, server),
    };
  }

  static Map<String, dynamic> _parseXrayVmess(String link) {
    final encoded = link.substring('vmess://'.length);
    final decoded = utf8.decode(base64.decode(_padBase64(encoded)));
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    final server = json['add']?.toString();
    final uuid = json['id']?.toString();
    if (server == null || uuid == null) {
      throw ConfigParserException('Invalid vmess link');
    }
    final port = int.tryParse(json['port']?.toString() ?? '') ?? 443;
    final params = <String, String>{
      if (json['net'] != null) 'type': json['net'].toString(),
      if (json['tls']?.toString() == 'tls') 'security': 'tls',
      if (json['sni'] != null) 'sni': json['sni'].toString(),
      if (json['host'] != null) 'host': json['host'].toString(),
      if (json['path'] != null) 'path': json['path'].toString(),
    };
    return {
      'tag': 'proxy',
      'protocol': 'vmess',
      'settings': {
        'vnext': [
          {
            'address': server,
            'port': port,
            'users': [
              {
                'id': uuid,
                'alterId': int.tryParse(json['aid']?.toString() ?? '') ?? 0,
                'security': json['scy']?.toString() ?? 'auto',
              },
            ],
          },
        ],
      },
      'streamSettings': _xrayStreamSettings(params, server),
    };
  }

  static Map<String, dynamic> _parseXrayShadowsocks(String link) {
    final uri = Uri.parse(link);
    final methodPassword = uri.userInfo.split(':');
    if (methodPassword.length != 2 || uri.host.isEmpty) {
      throw ConfigParserException('Invalid shadowsocks link');
    }
    return {
      'tag': 'proxy',
      'protocol': 'shadowsocks',
      'settings': {
        'servers': [
          {
            'address': uri.host,
            'port': uri.port > 0 ? uri.port : 8388,
            'method': methodPassword[0],
            'password': methodPassword[1],
          },
        ],
      },
    };
  }

  static Map<String, dynamic> _parseSingboxVless(String link) {
    final uri = Uri.parse(link);
    final uuid = uri.userInfo;
    final server = uri.host;
    if (uuid.isEmpty || server.isEmpty) {
      throw ConfigParserException('Invalid vless link');
    }
    final params = uri.queryParameters;
    return {
      'type': 'vless',
      'tag': 'proxy',
      'server': server,
      'server_port': uri.port > 0 ? uri.port : 443,
      'uuid': uuid,
      if (params['flow']?.isNotEmpty == true) 'flow': params['flow'],
      ..._singboxTls(params, server),
      ..._singboxTransport(params),
    };
  }

  static Map<String, dynamic> _parseSingboxTrojan(String link) {
    final uri = Uri.parse(link);
    final password = uri.userInfo;
    final server = uri.host;
    if (password.isEmpty || server.isEmpty) {
      throw ConfigParserException('Invalid trojan link');
    }
    return {
      'type': 'trojan',
      'tag': 'proxy',
      'server': server,
      'server_port': uri.port > 0 ? uri.port : 443,
      'password': password,
      ..._singboxTls(uri.queryParameters, server),
      ..._singboxTransport(uri.queryParameters),
    };
  }

  static Map<String, dynamic> _parseSingboxVmess(String link) {
    final encoded = link.substring('vmess://'.length);
    final decoded = utf8.decode(base64.decode(_padBase64(encoded)));
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    final server = json['add']?.toString();
    final uuid = json['id']?.toString();
    if (server == null || uuid == null) {
      throw ConfigParserException('Invalid vmess link');
    }
    final params = <String, String>{
      if (json['net'] != null) 'type': json['net'].toString(),
      if (json['tls']?.toString() == 'tls') 'security': 'tls',
      if (json['sni'] != null) 'sni': json['sni'].toString(),
      if (json['host'] != null) 'host': json['host'].toString(),
      if (json['path'] != null) 'path': json['path'].toString(),
    };
    return {
      'type': 'vmess',
      'tag': 'proxy',
      'server': server,
      'server_port': int.tryParse(json['port']?.toString() ?? '') ?? 443,
      'uuid': uuid,
      'alter_id': int.tryParse(json['aid']?.toString() ?? '') ?? 0,
      'security': json['scy']?.toString() ?? 'auto',
      ..._singboxTls(params, server),
      ..._singboxTransport(params),
    };
  }

  static Map<String, dynamic> _parseSingboxShadowsocks(String link) {
    final uri = Uri.parse(link);
    final methodPassword = uri.userInfo.split(':');
    if (methodPassword.length != 2 || uri.host.isEmpty) {
      throw ConfigParserException('Invalid shadowsocks link');
    }
    return {
      'type': 'shadowsocks',
      'tag': 'proxy',
      'server': uri.host,
      'server_port': uri.port > 0 ? uri.port : 8388,
      'method': methodPassword[0],
      'password': methodPassword[1],
    };
  }

  static Map<String, dynamic> _xrayStreamSettings(
    Map<String, String> params,
    String server,
  ) {
    final network = params['type'] ?? 'tcp';
    final stream = <String, dynamic>{'network': network};

    final security = params['security'];
    if (security == 'reality') {
      stream['security'] = 'reality';
      stream['realitySettings'] = {
        'serverName': params['sni'] ?? server,
        'publicKey': params['pbk'] ?? '',
        'shortId': params['sid'] ?? '',
        'fingerprint': params['fp'] ?? 'chrome',
      };
    } else if (security == 'tls' || params['sni']?.isNotEmpty == true) {
      stream['security'] = 'tls';
      stream['tlsSettings'] = {
        'serverName': params['sni'] ?? server,
        if (params['fp']?.isNotEmpty == true) 'fingerprint': params['fp'],
        'allowInsecure': params['allowInsecure'] == '1',
      };
    } else {
      stream['security'] = 'none';
    }

    if (network == 'ws') {
      stream['wsSettings'] = {
        'path': params['path'] ?? '/',
        if (params['host']?.isNotEmpty == true)
          'headers': {'Host': params['host']},
      };
    }

    return stream;
  }

  static Map<String, dynamic> _singboxTls(
    Map<String, String> params,
    String server,
  ) {
    final security = params['security'];
    if (security == 'reality') {
      return {
        'tls': {
          'enabled': true,
          'server_name': params['sni'] ?? server,
          'reality': {
            'enabled': true,
            'public_key': params['pbk'] ?? '',
            'short_id': params['sid'] ?? '',
          },
          if (params['fp']?.isNotEmpty == true) 'utls': {'enabled': true, 'fingerprint': params['fp']},
        },
      };
    }
    if (security == 'tls' || params['sni']?.isNotEmpty == true) {
      return {
        'tls': {
          'enabled': true,
          'server_name': params['sni'] ?? server,
          if (params['fp']?.isNotEmpty == true) 'utls': {'enabled': true, 'fingerprint': params['fp']},
        },
      };
    }
    return {};
  }

  static Map<String, dynamic> _singboxTransport(Map<String, String> params) {
    final network = params['type'] ?? 'tcp';
    if (network == 'ws') {
      return {
        'transport': {
          'type': 'ws',
          'path': params['path'] ?? '/',
          if (params['host']?.isNotEmpty == true) 'headers': {'Host': params['host']},
        },
      };
    }
    return {};
  }

  static String _padBase64(String value) {
    final padding = value.length % 4;
    if (padding == 0) {
      return value;
    }
    return value + '=' * (4 - padding);
  }
}
