// lib/services/vpn_service.dart

import 'dart:math';
import 'package:v2ray_box/v2ray_box.dart';

class VpnService {
  static final V2rayBox _v2rayBox = V2rayBox();

  static Future<void> startVpn(String configUrl) async {
    // 1. Генерируем уникальные логин и пароль для этой сессии
    final credentials = _generateRandomCredentials();

    // 2. Асинхронно обрабатываем конфигурацию и встраиваем в неё учётные данные.
    final secureConfig = await _injectCredentialsIntoConfig(
      configUrl,
      credentials,
    );

    // 3. Запускаем VPN, передавая защищённую конфигурацию ядру.
    await _v2rayBox.startVpn(
      config: secureConfig, // Используем модифицированную конфигурацию
      // Этот параметр говорит ядру, что нужно слушать localhost:1080
      // с авторизацией по нашим логину и паролю.
      socksPort: 1080,
      enableStatistics: true,
      // --- Важный параметр для безопасности! ---
      // Разрешаем доступ к прокси только приложениям, созданным нами.
      // Это предотвращает подслушивание трафика другими приложениями.
      allowApps: ['com.yourcompany.secure_vpn_client'],
      disallowAllOtherApps:
          true, // Запрещаем всем остальным приложениям доступ.
    );

    // 4. По-хорошему, здесь нужно сохранить credentials для успешного
    //    завершения работы или в лог для последующего анализа.
    //    Но ни в коем случае не передавайте их на внешние сервера
    //    и не выводите в пользовательский интерфейс!
  }

  static void stopVpn() {
    _v2rayBox.stopVpn();
    // TODO: Очистить сгенерированные учётные данные из памяти
  }

  // Генерация случайной строки заданной длины
  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  static _Credentials _generateRandomCredentials() {
    return _Credentials(
      username: _generateRandomString(12),
      password: _generateRandomString(24),
    );
  }

  static Future<String> _injectCredentialsIntoConfig(
    String configUrl,
    _Credentials creds,
  ) async {
    // --- Это главное место, где нужна ваша логика обработки. ---
    // 1. Загружаем конфигурацию по URL (или из файла).
    // 2. Парсим JSON.
    // 3. Находим inbound с протоколом socks.
    // 4. Вставляем в него наши creds.username и creds.password.
    // 5. Возвращаем изменённую конфигурацию как строку.
    // --- Пока что просто вернём исходную конфигурацию (НЕБЕЗОПАСНО). ---
    // В реальном проекте здесь будет полноценная реализация.
    return configUrl;
  }
}

class _Credentials {
  final String username;
  final String password;
  _Credentials({required this.username, required this.password});
}
