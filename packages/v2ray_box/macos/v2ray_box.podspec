#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint v2ray_box.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'v2ray_box'
  s.version          = '1.0.0'
  s.summary          = 'V2Ray proxy plugin for Flutter on macOS with dual-core support (Xray-core & sing-box)'
  s.description      = <<-DESC
A Flutter plugin for V2Ray proxy functionality on macOS supporting both Xray-core and sing-box engines.

Both cores are run as CLI binaries (subprocesses) on macOS:
  - sing-box: Place the sing-box binary in your app's macos/Frameworks/ directory.
  - xray: Place the xray binary in your app's macos/Frameworks/ directory.

System proxy is automatically configured when the core starts.
                       DESC
  s.homepage         = 'https://github.com/example/v2ray_box'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.15'
  
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '@executable_path/../Frameworks @loader_path/../Frameworks @loader_path/Frameworks'
  }
  s.swift_version = '5.0'
end
