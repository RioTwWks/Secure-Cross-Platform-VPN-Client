# Secure VPN Client (MVP)

**Кроссплатформенный VPN-клиент на Flutter с поддержкой Xray-core и sing-box**  
*Реализована защита от уязвимости неавторизованного SOCKS5-прокси (март 2026)*

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue.svg)](https://flutter.dev)
[![Xray-core](https://img.shields.io/badge/Xray--core-1.8.24+-green.svg)](https://github.com/XTLS/Xray-core)
[![sing-box](https://img.shields.io/badge/sing--box-1.10+-orange.svg)](https://github.com/SagerNet/sing-box)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

---

## 📌 Описание

**Secure VPN Client** — это безопасный и гибкий VPN-клиент, разработанный в рамках MVP (минимально жизнеспособного продукта). Приложение позволяет подключаться к VPN-серверам по протоколам VLESS, VMess, Shadowsocks, Trojan и другим (через ядра Xray-core и sing-box). Главное отличие от многих существующих клиентов — **полное устранение уязвимости, связанной с неаутентифицированным локальным SOCKS5-прокси**, которая была обнаружена весной 2026 года в таких приложениях, как Hiddify, v2rayNG, Happ и др.

Проект создан с нуля на Flutter для работы на пяти платформах: **Android, iOS, Windows, Linux, macOS**.

---

## 🔐 Ключевые особенности безопасности

- **Динамическая аутентификация SOCKS5**  
  При каждом запуске VPN генерируется уникальная пара логин/пароль для локального SOCKS5-прокси. Учетные данные никогда не сохраняются на диске и уничтожаются после остановки VPN.

- **Запрет доступа для сторонних приложений**  
  Локальный прокси-сервер привязан только к `127.0.0.1` и требует обязательной авторизации. В конфигурации ядра задаётся белый список пакетов (`allowApps`), имеющих доступ к прокси; всем остальным приложениям доступ запрещён.

- **Отсутствие открытых портов**  
  В отличие от уязвимых клиентов, наше приложение **не** слушает `0.0.0.0` и **не** оставляет порт `7890` без пароля. Каждая сессия использует случайный порт (по умолчанию 1080) и случайные учетные данные.

- **Поддержка переключения ядер**  
  Вы можете использовать либо Xray-core, либо sing-box. Оба движка настраиваются единообразно через наш безопасный враппер.

---

## 🧱 Технологический стек

| Компонент          | Технология                                     |
|--------------------|------------------------------------------------|
| Интерфейс и логика | Flutter (Dart)                                |
| VPN-туннелирование | Локальный форк [`packages/v2ray_box`](packages/v2ray_box) (патчи безопасности) |
| Ядро 1             | [Xray-core](https://github.com/XTLS/Xray-core) (Go, subprocess) |
| Ядро 2             | [sing-box](https://github.com/SagerNet/sing-box) (Go, subprocess) |
| Нативные мосты     | Android (Kotlin), iOS/macOS (Swift), Linux/Windows (C++ plugin) |

---

## 📋 Требования к окружению разработчика

- Flutter SDK `stable` (рекомендуется актуальный канал)
- Dart SDK `^3.11.0` (см. `secure_vpn_client/pubspec.yaml`)
- Для Android: Android Studio, SDK 23+, NDK
- Для iOS/macOS: Xcode 15+, CocoaPods
- Для Windows: Visual Studio 2022 с workload «Разработка классических приложений на C++»
- Для Linux: `clang`, `cmake`, `ninja-build`, `gtk3`
- Go `1.21+` (только если вы пересобираете ядра)

---

## 🚀 Быстрый старт (сборка MVP)

### 1. Клонирование репозитория
```bash
git clone https://github.com/RioTwWks/Secure-Cross-Platform-VPN-Client.git
cd Secure-Cross-Platform-VPN-Client/secure_vpn_client
```

> **Для AI-агентов (Cursor):** см. [.cursor/AGENTS.md](.cursor/AGENTS.md)

### 2. Установка зависимостей
```bash
flutter pub get
```

### 3. Настройка нативных разрешений

- **Android**  
  Откройте `android/app/src/main/AndroidManifest.xml` и убедитесь, что присутствует `<service>` для `VpnService` (см. инструкцию в `/docs/android_setup.md`).

- **iOS**  
  В Xcode добавьте `com.apple.developer.networking.vpn.api` в entitlements. Подробнее – `/docs/ios_setup.md`.

- **Linux**  
  См. `/docs/linux_setup.md` (proxy mode, `fetch_cores.sh`, geo assets).

- **Windows / macOS**  
  Скопируйте бинарники ядер в `windows/runner/resources/`, `macos/Runner/Resources/` (через `./scripts/fetch_cores.sh` из корня репозитория).

### 4. Подготовка бинарных файлов ядер (Xray-core, sing-box)

Из **корня репозитория** (не из `secure_vpn_client/`):

```bash
./scripts/fetch_cores.sh
```

Скрипт скачивает актуальные релизы Xray-core и sing-box, а также `geoip.dat` / `geosite.dat` (нужны для подписок xray с правилами `geosite:` / `geoip:`), и копирует их в:

```
secure_vpn_client/linux/runner/resources/     # xray, sing-box, geoip.dat, geosite.dat
secure_vpn_client/windows/runner/resources/
secure_vpn_client/macos/Runner/Resources/
secure_vpn_client/assets/binaries/            # android, ios, …
```

Файлы ядер **не хранятся в git** (см. `.gitignore`). На каждой машине и в CI нужно запускать `fetch_cores.sh` один раз или перед релизной сборкой.

### 5. Запуск на целевой платформе

```bash
# Android
flutter run -d android

# iOS (только на macOS)
flutter run -d ios

# Windows
flutter run -d windows

# Linux
flutter run -d linux

# macOS
flutter run -d macos
```

---

## 🧪 Тестирование безопасности

После сборки вы можете убедиться, что уязвимость устранена:

1. Запустите VPN-подключение.
2. Попробуйте подключиться к локальному SOCKS5-прокси (обычно `127.0.0.1:1080`) без пароля – соединение должно быть отклонено.
3. Используйте инструмент типа `curl --socks5 127.0.0.1:1080 https://api.ipify.org` – должен вернуться ваш реальный IP, но если вы укажете неверный пароль, запрос не пройдёт.
4. Скрипт-проверка из корня репозитория: `./scripts/security_probe.sh 1080` — неавторизованное подключение должно завершиться ошибкой.

На **Linux desktop** используется proxy mode: приложения нужно настроить на SOCKS5 `127.0.0.1:1080` с сессионным логином/паролем. Per-app изоляция — на Android (VPN mode).

---

## 📁 Структура репозитория

```
Secure-Cross-Platform-VPN-Client/
├── secure_vpn_client/            # Flutter-приложение (см. secure_vpn_client/README.md)
│   ├── lib/
│   │   ├── services/             # VpnService, CredentialService
│   │   ├── utils/                # ConfigParser, LinkConfigBuilder
│   │   ├── models/               # Profile, VpnEngine, Credentials
│   │   ├── providers/            # Riverpod
│   │   ├── screens/              # Home, Config, Settings
│   │   └── widgets/
│   ├── test/                     # Unit + security tests
│   └── linux/runner/resources/   # xray, sing-box, geo (gitignored)
├── packages/v2ray_box/           # Форк плагина (Linux desktop plugin, Android patches)
├── scripts/
│   ├── fetch_cores.sh            # Загрузка ядер и geo-файлов
│   ├── security_probe.sh         # Проверка SOCKS auth
│   └── sync_v2ray_box.sh
├── docs/                         # android_setup, ios_setup, linux_setup
└── .cursor/                      # Документация для AI-агентов (AGENTS.md)
```

---

## 🛠️ Планы развития (после MVP)

- [x] Поддержка подписок (V2Ray / sing-box, engine-specific User-Agent)
- [x] Переключение ядер xray / sing-box
- [x] Модульные тесты безопасности (`test/security_test.dart`, `test/config_parser_test.dart`)
- [x] Linux desktop: proxy mode, все 4 комбинации engine × profile
- [ ] Выбор сервера из списка подписки (сейчас — первый реальный entry)
- [ ] Android / iOS / Windows / macOS — полноценный E2E на устройствах
- [ ] Системный proxy на desktop
- [ ] Split tunneling (per-app) на мобильных платформах
- [ ] CI: `flutter analyze` + `flutter test` на push

Подробный backlog: [.cursor/tasks.md](.cursor/tasks.md)

---

## 🤝 Вклад в проект

Мы приветствуем любые исправления и улучшения. Пожалуйста, перед отправкой Pull Request:

1. Убедитесь, что `flutter analyze` проходит без ошибок (`secure_vpn_client/analysis_options.yaml`).
2. Добавьте тесты для новой функциональности безопасности.
3. Проверьте, что уязвимость SOCKS5 не появляется (используйте сценарии из `test/security_test.dart`).

---

## 📄 Лицензия

Проект распространяется под лицензией **GNU General Public License v3.0** (GPLv3), так как использует компоненты (Xray-core, sing-box) с аналогичными условиями. Полный текст лицензии – в файле [LICENSE](LICENSE).

---

## ⚠️ Отказ от ответственности

Данное программное обеспечение предоставляется «как есть» в образовательных и исследовательских целях. Разработчики не несут ответственности за любое незаконное использование приложения. Пользователь обязан соблюдать законодательство своей страны.

---

## 🙏 Благодарности

- Команде **XTLS** за Xray-core  
- **SagerNet** за sing-box  
- Авторам плагина `v2ray_box` (форк)  
- Сообществу Flutter за отличный фреймворк  

---

**Secure VPN Client** – ваш безопасный выбор в мире открытых VPN-решений. 🛡️