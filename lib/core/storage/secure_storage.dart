import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const _kAccessToken = 'accessToken';
  static const _kRefreshToken = 'refreshToken';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  static Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);

  static Future<void> clearAll() => _storage.deleteAll();

  static Future<void> clearTokens() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }
}
