# Development workflows

## Initial setup (new machine)

```bash
git clone https://github.com/RioTwWks/Secure-Cross-Platform-VPN-Client.git
cd Secure-Cross-Platform-VPN-Client

# Download xray, sing-box, geoip.dat, geosite.dat into runner/resources/
./scripts/fetch_cores.sh

cd secure_vpn_client
flutter pub get
flutter analyze
flutter test
```

## Daily dev loop (Linux)

```bash
cd secure_vpn_client
flutter run -d linux
```

- **Dart-only changes:** hot reload (`r`)
- **Native plugin changes** (`packages/v2ray_box/linux/*`): stop app, `flutter run -d linux` again
- **CMake / resources changes:** `flutter build linux --debug` or clean build

## Before committing

```bash
cd secure_vpn_client
flutter analyze
flutter test
```

Optional:

```bash
# From repo root, with VPN connected on Linux
./scripts/security_probe.sh
```

### Do not commit

- `secure_vpn_client/linux/runner/resources/{xray,sing-box,geoip.dat,geosite.dat}`
- `secure_vpn_client/assets/binaries/**` (except `.gitkeep`)
- `.cursor/mcp.json` (local MCP config)
- Credentials, subscription URLs, API keys

## Adding a feature — suggested order

1. **Dart logic** — models → utils → service → provider → UI
2. **Tests** — unit test in `test/` mirroring existing patterns
3. **Native** (if needed) — `packages/v2ray_box/<platform>/`
4. **Docs** — update `.cursor/troubleshooting.md` if new failure mode
5. **tasks.md** — mark completed or add backlog item

## Syncing v2ray_box fork

```bash
./scripts/sync_v2ray_box.sh   # if upstream sync is needed
```

Re-apply security patches after sync:

- Secure SOCKS inbound injection (Android sing-box `writeJsonConfigFile`)
- Credentials channel + config wipe on stop
- Linux `desktop_core.cc` / `v2ray_box_plugin.cc`

## Testing matrix (manual)

| Engine | Profile type | Expected |
|--------|--------------|----------|
| xray | Config link (`vless://…`) | Connect, status Started |
| xray | Subscription URL | Connect (needs geo assets) |
| singbox | Config link | Connect |
| singbox | Subscription URL | Connect (link list UA) |

## Release build notes

1. Run `./scripts/fetch_cores.sh` on CI or dev machine
2. Platform-specific signing (Android keystore, iOS provisioning)
3. See `docs/android_setup.md`, `docs/ios_setup.md`
