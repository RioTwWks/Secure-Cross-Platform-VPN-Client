# Agent Guide — Secure Cross-Platform VPN Client

**Start here.** This file orients Cursor agents to the repo layout, constraints, and safe edit paths.

## Repository layout

```
Secure-Cross-Platform-VPN-Client/
├── secure_vpn_client/          # Main Flutter app (run commands from here)
│   ├── lib/
│   │   ├── services/           # VpnService, CredentialService
│   │   ├── utils/              # ConfigParser, LinkConfigBuilder, crypto
│   │   ├── models/             # Profile, VpnEngine, Credentials
│   │   ├── providers/          # Riverpod state
│   │   ├── screens/            # Home, Config, Settings
│   │   └── widgets/
│   ├── test/                   # Unit + widget tests
│   ├── integration_test/
│   └── linux/runner/resources/ # xray, sing-box, geoip.dat, geosite.dat (gitignored)
├── packages/v2ray_box/         # Local fork — platform channels + native cores
│   └── linux/                  # Desktop plugin (proxy mode)
├── scripts/
│   ├── fetch_cores.sh          # Download xray/sing-box + geo assets
│   ├── security_probe.sh       # Local SOCKS auth probe
│   └── sync_v2ray_box.sh       # Sync fork patches
├── docs/                       # Platform setup (android_setup.md, ios_setup.md)
└── .cursor/                    # Agent docs (this folder)
```

## Golden rules (never break)

1. **SOCKS5 must always require auth** on `127.0.0.1` only — never `0.0.0.0`, never port `7890` unauthenticated.
2. **Credentials are per-session** — generate on connect, wipe on disconnect; never log or persist.
3. **Desktop = proxy mode**, not full TUN VPN (Linux/Windows/macOS use `VpnMode.proxy`).
4. **Do not commit core binaries** — they live in `*/runner/resources/` and are gitignored; use `scripts/fetch_cores.sh`.
5. **Edit the local fork** at `packages/v2ray_box/`, not pub.dev cache / plugin symlinks under `build/`.

## Primary code paths

| Flow | Entry | Notes |
|------|-------|-------|
| Connect | `VpnService.connect()` | `resolveProfileConfig` → `injectSecureSocksInbound` → `connectWithJson` |
| Subscription | `ConfigParser.parseFromUrl()` | Engine-specific User-Agent; see `troubleshooting.md` |
| Config link | `LinkConfigBuilder.buildFromLink()` | Used when profile is a `vless://` / `trojan://` etc. |
| Credentials | `CredentialService` + channel `secure_vpn/credentials` | Native side reads env vars on Linux |
| Linux core | `packages/v2ray_box/linux/desktop_core.cc` | Spawns xray/sing-box subprocess |

## Common commands

```bash
# From repo root
./scripts/fetch_cores.sh

# From secure_vpn_client/
flutter pub get
flutter analyze
flutter test
flutter run -d linux          # full restart after native plugin changes
flutter build linux --debug
```

## When changing…

| Area | Also update | Verify |
|------|-------------|--------|
| Config injection | `test/config_parser_test.dart`, `test/security_test.dart` | `flutter test` |
| Linux plugin | rebuild app (not hot reload) | connect all 4 engine×profile combos |
| v2ray_box fork | `scripts/sync_v2ray_box.sh` if syncing upstream | platform smoke test |
| Subscription parsing | `test/config_parser_test.dart` | real subscription URL + config link |

## Platform status (MVP)

| Platform | Mode | Status |
|----------|------|--------|
| Linux | Proxy | **Verified** — all 4 connect combinations |
| Android | VPN | Scaffold + fork patches; needs device test |
| iOS | VPN | Scaffold + docs; needs device test |
| Windows | Proxy | Plugin stub; cores via CMake install |
| macOS | Proxy | XrayProcess pattern in fork |

## Related docs

- [architecture.md](architecture.md) — components and data flow
- [troubleshooting.md](troubleshooting.md) — fixed bugs and diagnostic patterns
- [workflows.md](workflows.md) — build, test, debug checklists
- [tasks.md](tasks.md) — completed work + backlog
- [rules/](rules/) — scoped Cursor rules (`.mdc`)

## MCP servers (optional)

If configured in `.cursor/mcp.json`:

- **dart-mcp-server** — prefer over raw `flutter` shell when analyzing Dart
- **marionette** — UI debug on running Flutter app (needs VM service URI)

Do not commit secrets or subscription URLs into the repo.
