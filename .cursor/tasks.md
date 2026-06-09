# Project Tasks

> Agent entrypoint: [AGENTS.md](AGENTS.md) · Architecture: [architecture.md](architecture.md)

## Completed — MVP core

- [x] Project structure, `.cursorrules`, Riverpod UI
- [x] `CredentialService` + secure SOCKS injection (`ConfigParser`)
- [x] Local fork `packages/v2ray_box` with credential channel
- [x] `scripts/fetch_cores.sh` (xray, sing-box, geo assets)
- [x] Engine switching (xray / singbox)
- [x] Profile management (config link + subscription URL)
- [x] Security tests + `security_probe.sh`
- [x] Integration / widget tests

## Completed — Linux desktop

- [x] Linux plugin: setup, stop, start_with_json, status + credentials channels
- [x] Core discovery `bundle/lib/resources/`
- [x] Config write path fix + stale directory cleanup
- [x] Core stderr → UI error message
- [x] Geo assets copy to `~/.local/share/v2ray_box/assets/`
- [x] Subscription UA + decoy skipping + v2rayNG array selection
- [x] proxyOnly inbound sanitization + sing-box DNS migration
- [x] Xray routing `proxy` tag rewrite
- [x] **Verified:** xray/singbox × subscription/config (4 combinations)

## Security checklist

- [x] No hardcoded credentials
- [x] Bind 127.0.0.1 only
- [x] Mandatory SOCKS auth
- [x] Per-session credentials
- [x] Credentials cleared on stop

---

## Backlog — platform parity

- [ ] Android: end-to-end connect on physical device
- [ ] iOS: Network Extension + connect smoke test
- [ ] Windows: implement desktop plugin (mirror Linux `desktop_core.cc`)
- [ ] macOS: verify proxy mode connect with bundled cores
- [ ] System proxy integration on desktop (`setSystemProxy: true`)

## Backlog — UX & profiles

- [ ] Server picker when subscription returns multiple v2rayNG entries (currently first real entry)
- [ ] Profile import from clipboard / QR
- [ ] Connection stats + latency test in UI
- [ ] Localized strings (RU/EN)

## Backlog — security & hardening

- [ ] Auto-run `security_probe.sh` in CI when Linux integration test connects
- [ ] Fail closed if geo assets missing and config contains geosite/geoip rules
- [ ] Audit sing-box `mixed` / deprecated DNS paths on mobile VPN mode
- [ ] Certificate pinning for subscription fetch (optional)

## Backlog — engineering

- [ ] CI: `flutter analyze`, `flutter test` on push
- [ ] Reduce `packages/v2ray_box/example/` from fork if not needed (size)
- [ ] `docs/linux_setup.md` in `docs/` (mirror android/ios)
- [ ] Publish fork separately or document patch set vs upstream

---

## Agent maintenance

When fixing a new connect/config bug:

1. Add symptom → fix to [troubleshooting.md](troubleshooting.md)
2. Add regression test if Dart-side
3. Update [tasks.md](tasks.md) checklist or backlog
