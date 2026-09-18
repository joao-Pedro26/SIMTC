import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda os tokens de autenticação no armazenamento seguro do Android.
///
/// A preferência "manter conectado" decide se o par de tokens é gravado: sem
/// ela, a sessão vale só enquanto o app estiver aberto.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const String _accessKey = 'auth.accessToken';
  static const String _refreshKey = 'auth.refreshToken';
  static const String _keepSignedInKey = 'auth.keepSignedIn';

  Future<String?> readAccess() => _storage.read(key: _accessKey);

  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  Future<void> persist({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  /// Padrão: manter conectado (app de campo, usado várias vezes por dia).
  Future<bool> readKeepSignedIn() async {
    final value = await _storage.read(key: _keepSignedInKey);
    return value != 'false';
  }

  Future<void> setKeepSignedIn(bool value) {
    return _storage.write(key: _keepSignedInKey, value: '$value');
  }
}
