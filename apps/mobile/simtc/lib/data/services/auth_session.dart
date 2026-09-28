import 'dart:async';
import 'dart:convert';

import '../models/auth_user.dart';
import 'local/token_storage.dart';

/// Par de tokens da sessão corrente.
///
/// Fica em memória durante o uso e só vai para o armazenamento seguro quando o
/// usuário escolhe "manter conectado" — sem isso, fechar o app encerra a sessão.
class AuthSession {
  AuthSession(this._storage);

  final TokenStorage _storage;
  final StreamController<void> _expiredController =
      StreamController<void>.broadcast();

  String? _accessToken;
  String? _refreshToken;
  bool _keepSignedIn = true;

  /// Emite quando a sessão acabou (refresh recusado ou logout do servidor).
  Stream<void> get onExpired => _expiredController.stream;

  bool get keepSignedIn => _keepSignedIn;

  Future<String?> readAccessToken() async => _accessToken;

  Future<String?> readRefreshToken() async => _refreshToken;

  /// Carrega o que estiver salvo do uso anterior. Devolve true se havia sessão.
  Future<bool> restoreFromStorage() async {
    _keepSignedIn = await _storage.readKeepSignedIn();
    if (!_keepSignedIn) {
      await _storage.clear();
      return false;
    }

    _accessToken = await _storage.readAccess();
    _refreshToken = await _storage.readRefresh();
    return _accessToken != null && _refreshToken != null;
  }

  Future<void> start({
    required String accessToken,
    required String refreshToken,
    required bool keepSignedIn,
  }) async {
    _keepSignedIn = keepSignedIn;
    await _storage.setKeepSignedIn(keepSignedIn);
    await updateTokens(accessToken, refreshToken);
  }

  /// Usado também pelo `ApiClient` quando o token é renovado.
  Future<void> updateTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (_keepSignedIn) {
      await _storage.persist(accessToken: accessToken, refreshToken: refreshToken);
    }
  }

  /// Guarda o perfil que o servidor acabou de confirmar — só com "manter
  /// conectado", a mesma regra dos tokens.
  Future<void> saveUser(AuthUser user) async {
    if (!_keepSignedIn) return;
    await _storage.persistUser(jsonEncode(user.toJson()));
  }

  /// O último perfil guardado, ou null. Nunca lança: um perfil ilegível
  /// (armazenamento corrompido, formato antigo) vale como "não há perfil".
  Future<AuthUser?> readSavedUser() async {
    try {
      final json = await _storage.readUser();
      if (json == null) return null;
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic> ? AuthUser.fromJson(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.clear();
  }

  /// Chamado pelo `ApiClient` quando não dá mais para renovar o token.
  Future<void> expire() async {
    await clear();
    if (!_expiredController.isClosed) _expiredController.add(null);
  }

  void dispose() => _expiredController.close();
}
