/// Represents the current status of the VPN service
enum VpnStatus {
  stopped,
  starting,
  started,
  stopping;

  static VpnStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'stopped':
        return VpnStatus.stopped;
      case 'starting':
        return VpnStatus.starting;
      case 'started':
        return VpnStatus.started;
      case 'stopping':
        return VpnStatus.stopping;
      default:
        return VpnStatus.stopped;
    }
  }
}

/// Represents the VPN connection mode
enum VpnMode {
  vpn,
  proxy;

  static VpnMode fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'vpn':
        return VpnMode.vpn;
      case 'proxy':
        return VpnMode.proxy;
      default:
        return VpnMode.vpn;
    }
  }

  String get value => name;
}

/// Represents the per-app proxy mode
enum PerAppProxyMode {
  off,
  include,
  exclude;

  static PerAppProxyMode fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'off':
        return PerAppProxyMode.off;
      case 'include':
        return PerAppProxyMode.include;
      case 'exclude':
        return PerAppProxyMode.exclude;
      default:
        return PerAppProxyMode.off;
    }
  }

  String get value => name;
}

