# Secure VPN patches for v2ray_box

This directory is a fork of [pesaregorg/v2ray_box](https://github.com/pesaregorg/v2ray_box) with security-focused changes for Secure VPN Client.

## Changes vs upstream

1. **sing-box `connectWithJson` VPN mode** — `writeJsonConfigFile` writes `singbox_config.json` plus Xray TUN bridge (`active_config.json`) instead of a single file.
2. **Config wipe on disconnect** — `BoxService.wipeSensitiveConfigFiles()` removes JSON configs that may contain session credentials.
3. **Session credential channel** — `secure_vpn/credentials` MethodChannel stores per-session SOCKS metadata and passes env vars to sing-box subprocess.
4. **No additional unauthenticated SOCKS inbound** — `connectWithJson` uses the Dart-injected config as-is; link-based `generateConfig` still uses upstream inbounds (app uses `connectWithJson` only).

## Sync with upstream

```bash
./scripts/sync_v2ray_box.sh
```

Workflow:

1. `git fetch upstream`
2. `git rebase upstream/main` (resolve conflicts in patched files)
3. Run `flutter test` in `packages/v2ray_box`
4. Tag: `secure-vpn-<upstream-version>+<patch>`

## Patched files

- `android/.../bg/BoxService.kt`
- `android/.../V2rayBoxPlugin.kt`
- `android/.../SecureVpnCredentials.kt`
- `android/.../SecureVpnCredentialsPlugin.kt`
- `android/.../utils/SingboxProcess.kt`
