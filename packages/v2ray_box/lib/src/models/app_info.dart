/// Represents an installed application on the device
class AppInfo {
  /// Package name of the app
  final String packageName;

  /// Display name of the app
  final String name;

  /// Whether this is a system app
  final bool isSystemApp;

  /// Base64 encoded icon (optional)
  String? iconBase64;

  /// Whether this app is selected for per-app proxy
  bool isSelected;

  AppInfo({
    required this.packageName,
    required this.name,
    required this.isSystemApp,
    this.iconBase64,
    this.isSelected = false,
  });

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      packageName: json['package-name'] as String,
      name: json['name'] as String,
      isSystemApp: json['is-system-app'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'package-name': packageName,
      'name': name,
      'is-system-app': isSystemApp,
    };
  }

  @override
  String toString() => 'AppInfo(packageName: $packageName, name: $name)';
}

