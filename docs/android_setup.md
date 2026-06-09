# Android setup

1. Open `secure_vpn_client/android/app/src/main/AndroidManifest.xml` and verify VPN-related permissions are present.
2. Ensure `applicationId` is `com.example.secure_vpn_client` (used for per-app proxy allowlist).
3. Run `../../scripts/fetch_cores.sh` before release builds if you bundle custom core binaries.
4. Grant VPN permission when prompted on first connect.
5. Use `flutter run -d android` from `secure_vpn_client/`.

The `v2ray_box` fork registers its own `VpnService`; do not add a custom orphan service entry.
