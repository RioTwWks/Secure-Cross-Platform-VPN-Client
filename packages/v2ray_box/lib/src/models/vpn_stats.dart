/// Represents traffic statistics of the VPN connection
class VpnStats {
  /// Number of incoming connections
  final int connectionsIn;

  /// Number of outgoing connections
  final int connectionsOut;

  /// Current upload speed in bytes per second
  final int uplink;

  /// Current download speed in bytes per second
  final int downlink;

  /// Total uploaded bytes
  final int uplinkTotal;

  /// Total downloaded bytes
  final int downlinkTotal;

  const VpnStats({
    this.connectionsIn = 0,
    this.connectionsOut = 0,
    this.uplink = 0,
    this.downlink = 0,
    this.uplinkTotal = 0,
    this.downlinkTotal = 0,
  });

  factory VpnStats.fromJson(Map<String, dynamic> json) {
    return VpnStats(
      connectionsIn: (json['connections-in'] as num?)?.toInt() ?? 0,
      connectionsOut: (json['connections-out'] as num?)?.toInt() ?? 0,
      uplink: (json['uplink'] as num?)?.toInt() ?? 0,
      downlink: (json['downlink'] as num?)?.toInt() ?? 0,
      uplinkTotal: (json['uplink-total'] as num?)?.toInt() ?? 0,
      downlinkTotal: (json['downlink-total'] as num?)?.toInt() ?? 0,
    );
  }

  /// Format bytes to human readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Get formatted upload speed
  String get formattedUplink => '${formatBytes(uplink)}/s';

  /// Get formatted download speed
  String get formattedDownlink => '${formatBytes(downlink)}/s';

  /// Get formatted total upload
  String get formattedUplinkTotal => formatBytes(uplinkTotal);

  /// Get formatted total download
  String get formattedDownlinkTotal => formatBytes(downlinkTotal);

  @override
  String toString() {
    return 'VpnStats(uplink: $formattedUplink, downlink: $formattedDownlink, '
        'uplinkTotal: $formattedUplinkTotal, downlinkTotal: $formattedDownlinkTotal)';
  }
}

