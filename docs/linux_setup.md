# Linux setup

## Prerequisites

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
```

Flutter stable SDK (see `secure_vpn_client/pubspec.yaml` for Dart version).

## Core binaries

From repository root:

```bash
./scripts/fetch_cores.sh
```

This places into `secure_vpn_client/linux/runner/resources/`:

- `xray`, `sing-box`
- `geoip.dat`, `geosite.dat` (required for xray subscriptions with geosite/geoip routing)

These files are gitignored; each developer/CI job must fetch them.

## Run

```bash
cd secure_vpn_client
flutter pub get
flutter run -d linux
```

After editing `packages/v2ray_box/linux/*`, do a **full restart** (not hot reload).

## Runtime directories

| Path | Purpose |
|------|---------|
| `~/.local/share/v2ray_box/profiles/active_config.json` | Active core config (wiped on disconnect) |
| `~/.local/share/v2ray_box/assets/` | Xray geo databases |

## Mode

Linux desktop uses **proxy mode** (local authenticated SOCKS on `127.0.0.1:1080`), not a system TUN VPN.

Configure applications to use SOCKS5 `127.0.0.1:1080` with the session username/password (not persisted; generated per connect).

## Troubleshooting

See [.cursor/troubleshooting.md](../.cursor/troubleshooting.md) for detailed error → fix mapping.

## Security check

With VPN connected:

```bash
./scripts/security_probe.sh 1080
```

Unauthenticated probe must fail.
