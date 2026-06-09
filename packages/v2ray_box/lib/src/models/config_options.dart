import 'dart:convert';

/// Configuration options for the VPN service
class ConfigOptions {
  final bool blockAds;
  final String logLevel;
  final bool resolveDestination;
  final String ipv6Mode;
  final String remoteDnsAddress;
  final String directDnsAddress;
  final int mixedPort;
  final int localDnsPort;
  final int mtu;
  final bool strictRoute;
  final String connectionTestUrl;
  final int urlTestInterval;
  final bool enableClashApi;
  final int clashApiPort;
  final bool enableTun;
  final bool setSystemProxy;
  final bool bypassLan;
  final bool allowConnectionFromLan;
  final bool enableFakeDns;
  final bool enableDnsRouting;

  const ConfigOptions({
    this.blockAds = false,
    this.logLevel = 'warn',
    this.resolveDestination = false,
    this.ipv6Mode = 'disable',
    this.remoteDnsAddress = 'https://8.8.8.8/dns-query',
    this.directDnsAddress = 'local',
    this.mixedPort = 2080,
    this.localDnsPort = 6450,
    this.mtu = 9000,
    this.strictRoute = true,
    this.connectionTestUrl = 'http://www.gstatic.com/generate_204',
    this.urlTestInterval = 600,
    this.enableClashApi = true,
    this.clashApiPort = 6756,
    this.enableTun = true,
    this.setSystemProxy = false,
    this.bypassLan = true,
    this.allowConnectionFromLan = false,
    this.enableFakeDns = false,
    this.enableDnsRouting = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'block-ads': blockAds,
      'log-level': logLevel,
      'resolve-destination': resolveDestination,
      'ipv6-mode': ipv6Mode,
      'remote-dns-address': remoteDnsAddress,
      'remote-dns-domain-strategy': '',
      'direct-dns-address': directDnsAddress,
      'direct-dns-domain-strategy': '',
      'mixed-port': mixedPort,
      'tproxy-port': 0,
      'local-dns-port': localDnsPort,
      'tun-implementation': 'mixed',
      'mtu': mtu,
      'strict-route': strictRoute,
      'connection-test-url': connectionTestUrl,
      'url-test-interval': urlTestInterval,
      'enable-clash-api': enableClashApi,
      'clash-api-port': clashApiPort,
      'enable-tun': enableTun,
      'enable-tun-service': enableTun,
      'set-system-proxy': setSystemProxy,
      'bypass-lan': bypassLan,
      'allow-connection-from-lan': allowConnectionFromLan,
      'enable-fake-dns': enableFakeDns,
      'enable-dns-routing': enableDnsRouting,
      'independent-dns-cache': false,
      'rules': <dynamic>[],
      'mux': {
        'enable': false,
        'padding': false,
        'max-streams': 8,
        'protocol': 'h2mux',
      },
      'tls-tricks': {
        'enable-fragment': false,
        'fragment-size': '10-100',
        'fragment-sleep': '50-100',
        'mixed-sni-case': false,
        'enable-padding': false,
        'padding-size': '100-200',
      },
      'warp': {
        'enable': false,
        'mode': 'proxy_over_warp',
        'wireguard-config': '',
        'license-key': '',
        'account-id': '',
        'access-token': '',
        'clean-ip': '',
        'clean-port': 0,
        'noise': '10-15',
        'noise-size': '10-30',
        'noise-delay': '10-30',
        'noise-mode': 'm4',
      },
      'warp2': {
        'enable': false,
        'mode': 'proxy_over_warp',
        'wireguard-config': '',
        'license-key': '',
        'account-id': '',
        'access-token': '',
        'clean-ip': '',
        'clean-port': 0,
        'noise': '10-15',
        'noise-size': '10-30',
        'noise-delay': '10-30',
        'noise-mode': 'm4',
      },
      'region': 'other',
      'use-xray-core-when-possible': false,
      'execute-config-as-is': false,
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory ConfigOptions.fromJson(Map<String, dynamic> json) {
    return ConfigOptions(
      blockAds: json['block-ads'] as bool? ?? false,
      logLevel: json['log-level'] as String? ?? 'warn',
      resolveDestination: json['resolve-destination'] as bool? ?? false,
      ipv6Mode: json['ipv6-mode'] as String? ?? 'disable',
      remoteDnsAddress:
          json['remote-dns-address'] as String? ?? 'https://8.8.8.8/dns-query',
      directDnsAddress: json['direct-dns-address'] as String? ?? 'local',
      mixedPort: json['mixed-port'] as int? ?? 2080,
      localDnsPort: json['local-dns-port'] as int? ?? 6450,
      mtu: json['mtu'] as int? ?? 9000,
      strictRoute: json['strict-route'] as bool? ?? true,
      connectionTestUrl: json['connection-test-url'] as String? ??
          'http://www.gstatic.com/generate_204',
      urlTestInterval: json['url-test-interval'] as int? ?? 600,
      enableClashApi: json['enable-clash-api'] as bool? ?? true,
      clashApiPort: json['clash-api-port'] as int? ?? 6756,
      enableTun: json['enable-tun'] as bool? ?? true,
      setSystemProxy: json['set-system-proxy'] as bool? ?? false,
      bypassLan: json['bypass-lan'] as bool? ?? true,
      allowConnectionFromLan:
          json['allow-connection-from-lan'] as bool? ?? false,
      enableFakeDns: json['enable-fake-dns'] as bool? ?? false,
      enableDnsRouting: json['enable-dns-routing'] as bool? ?? true,
    );
  }
}

