import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Cliente HTTP do app.
///
/// Concentra três coisas que não devem ficar espalhadas pelos repositories: a
/// URL base do ambiente, o cabeçalho `Authorization` e a renovação do token
/// quando o backend responde 401.
///
/// Não conhece o `AuthRepository`: recebe funções para ler e gravar os tokens,
/// o que evita dependência circular entre os dois.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.readAccessToken,
    required this.readRefreshToken,
    required this.onTokensRenewed,
    required this.onSessionExpired,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      // O tratamento de erro é nosso; o dio não deve lançar antes da hora.
      validateStatus: (status) => status != null && status < 400,
    );
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  final Dio _dio;
  final Future<String?> Function() readAccessToken;
  final Future<String?> Function() readRefreshToken;
  final Future<void> Function(String accessToken, String refreshToken) onTokensRenewed;
  final Future<void> Function() onSessionExpired;

  static const String refreshPath = '/auth/refresh';

  /// Refresh em andamento — chamadas paralelas esperam o mesmo resultado.
  Future<_Refresh>? _pendingRefresh;

  Dio get dio => _dio;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path != refreshPath) {
      final token = await readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final response = error.response;
    final isExpiredToken = response?.statusCode == 401 &&
        error.requestOptions.path != refreshPath &&
        error.requestOptions.extra['retriedAfterRefresh'] != true;

    if (!isExpiredToken) {
      handler.next(error);
      return;
    }

    final refresh = await _refreshToken();
    final newToken = refresh.accessToken;
    if (newToken == null) {
      // Sessão encerrada pelo servidor: segue o 401 original. Renovação que
      // não chegou a ser respondida (sem rede, tempo esgotado, 5xx): segue o
      // erro dela — quem chamou vê "sem conexão", não "não autorizado", e a
      // sessão continua valendo.
      handler.next(refresh.failure ?? error);
      return;
    }

    try {
      final options = error.requestOptions;
      options.headers['Authorization'] = 'Bearer $newToken';
      options.extra['retriedAfterRefresh'] = true;
      final retried = await _dio.fetch<dynamic>(options);
      handler.resolve(retried);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Renova o par de tokens. Devolve o access token novo, a sessão encerrada
  /// (aí o app precisa mandar o usuário para o login) ou a falha que impediu
  /// a renovação sem encerrar a sessão.
  Future<_Refresh> _refreshToken() {
    return _pendingRefresh ??= _performRefresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<_Refresh> _performRefresh() async {
    final refreshToken = await readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await onSessionExpired();
      return const _Refresh.expired();
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        refreshPath,
        data: {'refreshToken': refreshToken},
      );
      final data = response.data ?? const {};
      final accessToken = data['accessToken'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;

      if (accessToken == null || newRefreshToken == null) {
        await onSessionExpired();
        return const _Refresh.expired();
      }

      // A sessão acabou enquanto a renovação estava no ar (o "Sair", ou outro
      // login): gravar os tokens novos traria de volta quem saiu na próxima
      // abertura do app (Fase 8A). Nada é gravado, e quem chamou recebe o
      // 401 original — a sessão já foi encerrada por quem a encerrou.
      if (await readRefreshToken() != refreshToken) {
        return const _Refresh.expired();
      }

      await onTokensRenewed(accessToken, newRefreshToken);
      return _Refresh.renewed(accessToken);
    } on DioException catch (refreshError) {
      // Só o servidor recusando o refresh token (4xx) encerra a sessão
      // (decisão de 29/09/2026). Sem rede, tempo esgotado ou servidor fora do
      // ar (5xx), o token pode continuar valendo: a chamada falha agora e a
      // próxima com rede tenta renovar de novo. Antes, qualquer falha aqui
      // deslogava — e o login exige rede.
      final status = refreshError.response?.statusCode;
      if (status != null && status >= 400 && status < 500) {
        await onSessionExpired();
        return const _Refresh.expired();
      }
      return _Refresh.failed(refreshError);
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _run(() => _dio.get<T>(path, queryParameters: queryParameters));
  }

  Future<Response<T>> post<T>(String path, {Object? data}) {
    return _run(() => _dio.post<T>(path, data: data));
  }

  Future<Response<T>> patch<T>(String path, {Object? data}) {
    return _run(() => _dio.patch<T>(path, data: data));
  }

  Future<Response<T>> delete<T>(String path) {
    return _run(() => _dio.delete<T>(path));
  }

  Future<Response<T>> _run<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// Desfecho de uma renovação de token.
class _Refresh {
  const _Refresh.renewed(String this.accessToken) : failure = null;
  const _Refresh.expired()
      : accessToken = null,
        failure = null;
  const _Refresh.failed(DioException this.failure) : accessToken = null;

  /// O access token novo — nulo quando não renovou.
  final String? accessToken;

  /// Por que não renovou sem a sessão ter acabado (sem rede, 5xx). Nulo
  /// quando renovou ou quando o servidor encerrou a sessão.
  final DioException? failure;
}
