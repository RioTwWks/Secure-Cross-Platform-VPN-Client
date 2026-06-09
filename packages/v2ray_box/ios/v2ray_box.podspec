#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint v2ray_box.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'v2ray_box'
  s.version          = '1.0.0'
  s.summary          = 'V2Ray VPN plugin for Flutter with dual-core support (Xray-core & sing-box)'
  s.description      = <<-DESC
A Flutter plugin for V2Ray VPN functionality supporting both Xray-core and sing-box engines.

For sing-box (default core):
  Build Libbox.xcframework from the official SagerNet/sing-box repository
  and place it in your app's ios/Frameworks/ directory.

For Xray-core:
  Xray support requires custom PacketTunnel integration with XTLS/libXray.
  The default PacketTunnel shipped by this plugin runs sing-box only.
                       DESC
  s.homepage         = 'https://github.com/example/v2ray_box'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  
  # Libbox.xcframework is NOT bundled with this plugin package.
  # Build it from official sing-box source and place it at ios/Frameworks/Libbox.xcframework.
  s.vendored_frameworks = 'Frameworks/Libbox.xcframework'
  
  s.frameworks = 'NetworkExtension'
  s.libraries = 'resolv'
  
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC -all_load'
  }
  s.swift_version = '5.0'

  # Privacy manifest
  s.resource_bundles = {'v2ray_box_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
