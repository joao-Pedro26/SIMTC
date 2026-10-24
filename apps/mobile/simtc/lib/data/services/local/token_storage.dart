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
  static const String _userKey = 'auth.user';
  static const String _apiBaseUrlKey = 'app.apiBaseUrl';

  Future<String?> readAccess() => _storage.read(key: _accessKey);

  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  Future<void> persist({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  /// Último perfil que o servidor confirmou, em JSON — é o que permite abrir
  /// o app sem rede. Segue a mesma regra dos tokens: só existe com "manter
  /// conectado" e some junto com eles em [clear].
  Future<String?> readUser() => _storage.read(key: _userKey);

  Future<void> persistUser(String json) => _storage.write(key: _userKey, value: json);

  /// Apaga só o perfil salvo, sem mexer nos tokens — um login novo não herda
  /// o perfil de quem entrou antes (ver `AuthSession.start`).
  Future<void> deleteUser() => _storage.delete(key: _userKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
  }

  /// O endereço da API com que o app falou na última abertura (ver
  /// `DeviceDataService.resetIfServerChanged`). Fica fora do [clear]: sair da
  /// conta não muda de servidor.
  Future<String?> readApiBaseUrl() => _storage.read(key: _apiBaseUrlKey);

  Future<void> saveApiBaseUrl(String url) =>
      _storage.write(key: _apiBaseUrlKey, value: url);

  /// Padrão: manter conectado (app de campo, usado várias vezes por dia).
  Future<bool> readKeepSignedIn() async {
    final value = await _storage.read(key: _keepSignedInKey);
    return value != 'false';
  }

  Future<void> setKeepSignedIn(bool value) {
    return _storage.write(key: _keepSignedInKey, value: '$value');
  }
}
