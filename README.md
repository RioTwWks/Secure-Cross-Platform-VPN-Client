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
| VPN-туннелирование | Плагин [`v2ray_box`](https://pub.dev/packages/v2ray_box) (форк с патчами безопасности) |
| Ядро 1             | [Xray-core](https://github.com/XTLS/Xray-core) (Go) |
| Ядро 2             | [sing-box](https://github.com/SagerNet/sing-box) (Go) |
| Нативные мосты     | Android (Kotlin/JNI), iOS (Swift), Windows/Linux/macOS (Go FFI) |

---

## 📋 Требования к окружению разработчика

- Flutter SDK `>=3.22.0` (канал `stable`)
- Dart SDK `>=3.4.0`
- Для Android: Android Studio, SDK 23+, NDK
- Для iOS/macOS: Xcode 15+, CocoaPods
- Для Windows: Visual Studio 2022 с workload «Разработка классических приложений на C++»
- Для Linux: `clang`, `cmake`, `ninja-build`, `gtk3`
- Go `1.21+` (только если вы пересобираете ядра)

---

## 🚀 Быстрый старт (сборка MVP)

### 1. Клонирование репозитория
```bash
git clone https://github.com/yourusername/secure_vpn_client.git
cd secure_vpn_client
```

### 2. Установка зависимостей
```bash
flutter pub get
```

### 3. Настройка нативных разрешений

- **Android**  
  Откройте `android/app/src/main/AndroidManifest.xml` и убедитесь, что присутствует `<service>` для `VpnService` (см. инструкцию в `/docs/android_setup.md`).

- **iOS**  
  В Xcode добавьте `com.apple.developer.networking.vpn.api` в entitlements. Подробнее – `/docs/ios_setup.md`.

- **Windows / Linux / macOS**  
  Следуйте инструкциям плагина `v2ray_box` (скопируйте бинарные файлы ядер в соответствующие папки: `windows/runner/resources/`, `linux/runner/resources/`, `macos/Resources/`).

### 4. Подготовка бинарных файлов ядер (Xray-core, sing-box)

Скачайте готовые сборки с официальных релизов или скомпилируйте сами:

```bash
# Пример для Xray-core (Linux)
wget https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip
unzip Xray-linux-64.zip -d assets/binaries/linux/
```

Разместите их в папке `assets/binaries/` согласно структуре:
```
assets/binaries/
  android/arm64-v8a/xray
  android/armeabi-v7a/xray
  ios/universal/xray
  windows/x64/xray.exe
  linux/x64/xray
  macos/x64/xray
  (аналогично для sing-box)
```

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
4. Запустите стороннее приложение, которое пытается сканировать порт 1080 – доступ должен быть запрещён (благодаря `disallowAllOtherApps: true`).

---

## 📁 Структура проекта (MVP)

```
lib/
├── main.dart                     # Точка входа
├── services/
│   └── vpn_service.dart          # Логика VPN с динамической аутентификацией
├── models/
│   ├── profile.dart              # Модель конфигурации
│   └── credentials.dart          # Учетные данные (временные)
├── screens/
│   ├── home_screen.dart          # Главный экран (подключить/отключить)
│   └── config_screen.dart        # Добавление конфигураций по URL/файлу
├── utils/
│   ├── config_parser.dart        # Парсинг и инъекция учётных данных в JSON
│   └── crypto_utils.dart         # Генерация случайных паролей (Random.secure)
└── widgets/
    ├── connection_button.dart
    └── status_indicator.dart

assets/
└── binaries/                     # Скомпилированные Xray-core и sing-box (см. выше)

android/                          # Нативные файлы Android (разрешения, сервис)
ios/                              # Нативные файлы iOS (entitlements, Podfile)
windows/                          # Плагин v2ray_box и ресурсы
linux/                            # Аналогично
macos/                            # Аналогично
```

---

## 🛠️ Планы развития (после MVP)

- [ ] Графический интерфейс выбора протоколов и настройки маршрутизации  
- [ ] Поддержка подписей (V2Ray subscription)  
- [ ] Интеграция с WireGuard через отдельный плагин  
- [ ] Режим «только нужные приложения» (split tunneling)  
- [ ] Автоматическое обновление гео-баз (GeoIP, GeoSite)  
- [ ] Модульные тесты для всех критических компонентов безопасности  

---

## 🤝 Вклад в проект

Мы приветствуем любые исправления и улучшения. Пожалуйста, перед отправкой Pull Request:

1. Убедитесь, что ваш код соответствует `analysis_options.yaml` (линтер Flutter).
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