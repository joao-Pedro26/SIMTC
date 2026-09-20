import 'package:flutter/foundation.dart';

import '../../utils/result.dart';
import '../models/auth_user.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../services/auth_session.dart';

/// Autenticação do app — sem nenhum atalho de desenvolvimento: se a API recusa,
/// o login falha.
class AuthRepository extends ChangeNotifier {
  AuthRepository({required ApiClient apiClient, required AuthSession session})
      : _api = apiClient,
        _session = session;

  final ApiClient _api;
  final AuthSession _session;

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  static const String _invalidCredentials = 'E-mail ou senha incorretos.';
  static const String _roleNotAllowed =
      'Esta conta não tem acesso ao app. Use o portal web.';
  static const String _sessionEnded = 'Sua sessão expirou. Entre de novo.';

  /// Entra com e-mail e senha. A senha não é aparada: espaços podem fazer parte dela.
  Future<Result<AuthUser>> login({
    required String email,
    required String password,
    required bool keepSignedIn,
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      );

      final data = response.data ?? const <String, dynamic>{};
      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;
      if (accessToken == null || refreshToken == null) {
        return Failure(Exception('login sem tokens'), _invalidCredentials);
      }

      await _session.start(
        accessToken: accessToken,
        refreshToken: refreshToken,
        keepSignedIn: keepSignedIn,
      );

      final user = await _loadCurrentUser(accessToken);
      if (user == null) {
        await logout();
        return Failure(Exception('perfil não permitido'), _roleNotAllowed);
      }

      _currentUser = user;
      notifyListeners();
      return Success(user);
    } on ApiException catch (error) {
      await _session.clear();
      return Failure(
        error,
        error.statusCode == 401 ? _invalidCredentials : error.message,
      );
    }
  }

  /// Tenta retomar a sessão salva na abertura do app.
  Future<Result<AuthUser>> restoreSession() async {
    final bool hasTokens;
    try {
      hasTokens = await _session.restoreFromStorage();
    } catch (error) {
      // A leitura do armazenamento seguro pode falhar por motivo fora do app:
      // a keystore do Android é invalidada quando o aparelho restaura um backup
      // ou o usuário troca o bloqueio de tela. Sem este catch, a exceção sobe
      // até a tela de abertura e o app fica parado nela para sempre. Tratar
      // como "não há sessão salva" manda para o login, que é recuperável.
      return Failure(Exception('$error'), _sessionEnded);
    }

    if (!hasTokens) {
      return Failure(Exception('sem sessão salva'), _sessionEnded);
    }

    try {
      final accessToken = await _session.readAccessToken();
      final user = await _loadCurrentUser(accessToken ?? '');
      if (user == null) {
        await logout();
        return Failure(Exception('perfil não permitido'), _roleNotAllowed);
      }

      _currentUser = user;
      notifyListeners();
      return Success(user);
    } on ApiException catch (error) {
      if (error.statusCode == 401) await _session.clear();
      return Failure(error, error.isNetworkError ? error.message : _sessionEnded);
    }
  }

  /// Pede o e-mail de redefinição de senha. O backend responde 204 mesmo quando
  /// o e-mail não existe, para não revelar quais contas estão cadastradas — a
  /// tela mostra a mesma mensagem nos dois casos.
  Future<Result<void>> requestPasswordReset(String email) async {
    try {
      await _api.post<void>('/auth/forgot-password', data: {'email': email.trim()});
      return const Success<void>(null);
    } on ApiException catch (error) {
      return Failure(error, error.message);
    }
  }

  Future<void> logout() async {
    try {
      await _api.post<void>('/auth/logout');
    } on ApiException {
      // Sem rede ou token já inválido: a sessão local é limpa de qualquer forma.
    }
    await _session.clear();
    _currentUser = null;
    notifyListeners();
  }

  /// Chamado quando o `ApiClient` desiste de renovar o token.
  void handleSessionExpired() {
    if (_currentUser == null) return;
    _currentUser = null;
    notifyListeners();
  }

  Future<AuthUser?> _loadCurrentUser(String accessToken) async {
    final response = await _api.get<Map<String, dynamic>>('/auth/me');
    final data = response.data ?? const <String, dynamic>{};
    final payload = decodeJwtPayload(accessToken);
    return AuthUser.fromMeJson(
      data,
      consultantId: payload?['consultantId'] as String?,
    );
  }
}
