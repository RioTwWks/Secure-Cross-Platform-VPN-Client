# Cursor agent context

Documentation and rules for AI agents working in this repository.

## Start here

| File | Purpose |
|------|---------|
| [AGENTS.md](AGENTS.md) | **Main entry** — layout, golden rules, commands |
| [architecture.md](architecture.md) | Components, data flow, config formats |
| [troubleshooting.md](troubleshooting.md) | Known errors and fixes (especially Linux + subscriptions) |
| [workflows.md](workflows.md) | Setup, dev loop, commit checklist |
| [tasks.md](tasks.md) | Done / backlog |

## Rules (auto-applied by Cursor)

| Rule | Scope |
|------|-------|
| [rules/project-overview.mdc](rules/project-overview.mdc) | Always |
| [rules/dart-flutter.mdc](rules/dart-flutter.mdc) | `secure_vpn_client/**/*.dart` |
| [rules/linux-native-plugin.mdc](rules/linux-native-plugin.mdc) | `packages/v2ray_box/linux/**` |
| [rules/security-config.mdc](rules/security-config.mdc) | Config + services + plugin |
| [rules/subscriptions.mdc](rules/subscriptions.mdc) | Subscription parsing |

## Local-only (do not commit secrets)

- `mcp.json` — MCP server configuration
- `settings.json` — editor preferences for this workspace

## Human docs

- [docs/linux_setup.md](../docs/linux_setup.md)
- [docs/android_setup.md](../docs/android_setup.md)
- [docs/ios_setup.md](../docs/ios_setup.md)
