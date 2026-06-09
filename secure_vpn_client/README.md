# Secure VPN Client (Flutter app)

Основное Flutter-приложение репозитория [Secure-Cross-Platform-VPN-Client](../README.md).

Кроссплатформенный VPN-клиент на **Xray-core** и **sing-box** с динамической аутентификацией локального SOCKS5 (`127.0.0.1:1080`).

## Быстрый старт

```bash
# Из корня репозитория — скачать ядра и geo-файлы
cd ..
./scripts/fetch_cores.sh

# Вернуться в приложение
cd secure_vpn_client
flutter pub get
flutter run -d linux    # или android / windows / macos / ios
```

После изменений в `packages/v2ray_box/linux/` нужен **полный перезапуск** (`flutter run`), не hot reload.

## Зависимости

- Локальный форк плагина: `packages/v2ray_box` (path dependency в `pubspec.yaml`)
- State management: **Riverpod**
- Dart SDK: `^3.11.0` (см. `pubspec.yaml`)

## Структура `lib/`

```
lib/
├── main.dart
├── models/          # Profile, VpnEngine, Credentials
├── providers/       # Riverpod (profiles, engine, VPN status)
├── screens/         # Home, Config (profiles), Settings
├── services/        # VpnService, CredentialService
├── utils/           # ConfigParser, LinkConfigBuilder, crypto
└── widgets/
```

## Тесты и линтер

```bash
flutter analyze
flutter test
```

## Платформы

| Платформа | Режим | Документация |
|-----------|-------|--------------|
| Linux | Proxy (SOCKS) | [docs/linux_setup.md](../docs/linux_setup.md) |
| Android | VPN (TUN) | [docs/android_setup.md](../docs/android_setup.md) |
| iOS | VPN | [docs/ios_setup.md](../docs/ios_setup.md) |
| Windows / macOS | Proxy | см. корневой README |

Бинарники `xray`, `sing-box`, `geoip.dat`, `geosite.dat` лежат в `linux/runner/resources/` (и аналогах) — **не в git**, ставятся через `fetch_cores.sh`.

## Безопасность

- Учётные данные SOCKS генерируются на каждую сессию и стираются при disconnect.
- Подробности и чеклист: [test/security_test.dart](test/security_test.dart), [../scripts/security_probe.sh](../scripts/security_probe.sh).

## Для разработчиков / AI-агентов

- [../.cursor/AGENTS.md](../.cursor/AGENTS.md) — карта репозитория и правила для агентов
- [../.cursor/troubleshooting.md](../.cursor/troubleshooting.md) — типичные ошибки Linux и подписок
