# iOS setup

1. Open `secure_vpn_client/ios/Runner.xcworkspace` in Xcode.
2. Add the **Network Extensions** capability and enable **Packet Tunnel**.
3. Add entitlement `com.apple.developer.networking.vpn.api` to the Runner target and tunnel extension.
4. Configure a valid development team and provisioning profile.
5. Copy core binaries to the paths expected by `v2ray_box` (see plugin README) or use bundled xcframeworks.
6. Run `flutter run -d ios` from `secure_vpn_client/` on macOS.

iOS requires a paid Apple Developer account for on-device VPN testing.
