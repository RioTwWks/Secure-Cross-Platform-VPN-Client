# Project Tasks - MVP

## Completed
- [x] Project structure created
- [x] .cursorrules configured
- [x] Added v2ray_box plugin (local fork in packages/v2ray_box)
- [x] Implement dynamic credential generation service (Dart)
- [x] Write platform channel to pass credentials to Go binary
- [x] Build Xray-core for all platforms (scripts/fetch_cores.sh)
- [x] Build sing-box for all platforms (scripts/fetch_cores.sh)
- [x] Modify v2ray_box plugin to accept inbound credentials
- [x] Add UI for subscription/profile management
- [x] Implement engine switching
- [x] Test vulnerability: attempt to connect to local SOCKS5 without password -> should fail (security_test.dart + security_probe.sh)
- [x] Write integration tests

## Linux desktop — verified working
- [x] Linux plugin: setup / stop / start_with_json, status channel, credentials channel
- [x] Core binary discovery (`bundle/lib/resources/xray`, `sing-box`)
- [x] Config write fix (`active_config.json` path + stale directory cleanup)
- [x] Core stderr surfaced in UI (real startup errors, not generic message)
- [x] Xray geo assets: `geoip.dat` / `geosite.dat` via fetch_cores.sh + copy to `~/.local/share/v2ray_box/assets/`
- [x] Subscription fetch: engine-specific User-Agent (v2rayNG / sing-box)
- [x] Subscription parsing: skip decoy links/entries, v2rayNG JSON array → first real server
- [x] Config sanitization for desktop proxy mode (strip tun/mixed/dns inbounds, legacy sing-box DNS migration)
- [x] Xray subscription routing fix (`outboundTag: proxy` → real outbound tag)
- [x] End-to-end connect on Linux: xray/singbox × subscription/config link (all 4 combinations)

## Security Checklist
- [x] No hardcoded credentials
- [x] Local port bound only to 127.0.0.1
- [x] Authentication mandatory
- [x] Credentials regenerated per session
- [x] Credentials cleared from memory after stop
