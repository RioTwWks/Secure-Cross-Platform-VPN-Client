/// Represents cumulative traffic data stored persistently
class TotalTraffic {
  /// Total uploaded bytes (persisted across sessions)
  final int upload;

  /// Total downloaded bytes (persisted across sessions)
  final int download;

  const TotalTraffic({
    this.upload = 0,
    this.download = 0,
  });

  factory TotalTraffic.fromJson(Map<String, dynamic> json) {
    return TotalTraffic(
      upload: (json['upload'] as num?)?.toInt() ?? 0,
      download: (json['download'] as num?)?.toInt() ?? 0,
    );
  }

  /// Get total traffic (upload + download)
  int get total => upload + download;

  /// Format bytes to human readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Get formatted upload
  String get formattedUpload => formatBytes(upload);

  /// Get formatted download
  String get formattedDownload => formatBytes(download);

  /// Get formatted total
  String get formattedTotal => formatBytes(total);

  @override
  String toString() {
    return 'TotalTraffic(upload: $formattedUpload, download: $formattedDownload, total: $formattedTotal)';
  }
}

