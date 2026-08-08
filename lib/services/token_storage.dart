import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the JWT in the platform's secure storage (Keychain on iOS,
/// EncryptedSharedPreferences on Android) instead of plain SharedPreferences,
/// since this token grants full access to a user's account.
class TokenStorage {
  static const _tokenKey = 'auth_token';
  final _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
