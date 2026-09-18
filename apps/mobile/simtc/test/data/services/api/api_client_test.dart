import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';

/// Resposta programada para o adaptador falso.
class _Reply {
  const _Reply(this.statusCode, [this.body = const <String, dynamic>{}]);

  final int statusCode;
  final Map<String, dynamic> body;
}

/// Adaptador que responde sem rede: cada requisição consome a próxima resposta
/// da fila e fica registrada para inspeção no teste.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.replies);

  final List<_Reply> replies;
  final List<RequestOptions> requests = [];
  DioExceptionType? throwNetworkError;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (throwNetworkError != null) {
      throw DioException(requestOptions: options, type: throwNetworkError!);
    }

    final reply = replies.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeAdapter adapter;
  late List<String> renewedTokens;
  late int sessionExpiredCalls;
  String? accessToken;
  String? refreshToken;

  ApiClient buildClient(List<_Reply> replies) {
    adapter = _FakeAdapter(replies);
    renewedTokens = [];
    sessionExpiredCalls = 0;
    final dio = Dio()..httpClientAdapter = adapter;

    return ApiClient(
      baseUrl: 'http://localhost:3001/api',
      dio: dio,
      readAccessToken: () async => accessToken,
      readRefreshToken: () async => refreshToken,
      onTokensRenewed: (access, refresh) async {
        accessToken = access;
        refreshToken = refresh;
        renewedTokens.add(access);
      },
      onSessionExpired: () async => sessionExpiredCalls++,
    );
  }

  setUp(() {
    accessToken = 'token-velho';
    refreshToken = 'refresh-1';
  });

  test('envia o access token no cabeçalho Authorization', () async {
    final client = buildClient([const _Reply(200, {'ok': true})]);

    await client.get<Map<String, dynamic>>('/training-sessions');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer token-velho');
  });

  test('em 401, renova o token e repete a requisição uma vez', () async {
    final client = buildClient([
      const _Reply(401, {'message': 'Unauthorized'}),
      const _Reply(200, {'accessToken': 'token-novo', 'refreshToken': 'refresh-2'}),
      const _Reply(200, {'data': []}),
    ]);

    final response = await client.get<Map<String, dynamic>>('/training-sessions');

    expect(response.statusCode, 200);
    expect(renewedTokens, ['token-novo']);
    expect(adapter.requests.map((r) => r.path).toList(),
        ['/training-sessions', '/auth/refresh', '/training-sessions']);
    expect(adapter.requests.last.headers['Authorization'], 'Bearer token-novo');
    expect(sessionExpiredCalls, 0);
  });

  test('sem refresh token, avisa que a sessão expirou e propaga o 401', () async {
    refreshToken = null;
    final client = buildClient([const _Reply(401, {'message': 'Unauthorized'})]);

    await expectLater(
      client.get<Map<String, dynamic>>('/auth/me'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(sessionExpiredCalls, 1);
  });

  test('se o refresh também falhar, não repete a requisição original', () async {
    final client = buildClient([
      const _Reply(401, {'message': 'Unauthorized'}),
      const _Reply(401, {'message': 'Refresh token inválido ou expirado'}),
    ]);

    await expectLater(
      client.get<Map<String, dynamic>>('/training-sessions'),
      throwsA(isA<ApiException>()),
    );
    expect(sessionExpiredCalls, 1);
    expect(adapter.requests, hasLength(2));
  });

  test('a rota de refresh não leva Authorization', () async {
    final client = buildClient([
      const _Reply(401, {'message': 'Unauthorized'}),
      const _Reply(200, {'accessToken': 'token-novo', 'refreshToken': 'refresh-2'}),
      const _Reply(200, {'data': []}),
    ]);

    await client.get<Map<String, dynamic>>('/training-sessions');

    final refreshRequest =
        adapter.requests.firstWhere((r) => r.path == ApiClient.refreshPath);
    expect(refreshRequest.headers.containsKey('Authorization'), isFalse);
  });

  test('traduz a mensagem de erro do backend', () async {
    final client = buildClient([
      const _Reply(409, {
        'message': 'Participantes aprovados não podem ser reavaliados',
        'error': 'Conflict',
        'statusCode': 409,
      }),
    ]);

    await expectLater(
      client.post<Map<String, dynamic>>('/practical-assessments/assign'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message',
                'Participantes aprovados não podem ser reavaliados'),
      ),
    );
  });

  test('junta as mensagens de validação do NestJS', () async {
    final client = buildClient([
      const _Reply(400, {
        'message': ['email must be an email', 'password should not be empty'],
        'statusCode': 400,
      }),
    ]);

    await expectLater(
      client.post<Map<String, dynamic>>('/auth/login'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message',
          'email must be an email\npassword should not be empty')),
    );
  });

  test('erro de rede vira ApiException marcada como falta de conexão', () async {
    final client = buildClient([]);
    adapter.throwNetworkError = DioExceptionType.connectionError;

    await expectLater(
      client.get<Map<String, dynamic>>('/training-sessions'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.isNetworkError, 'isNetworkError', isTrue)
            .having((e) => e.statusCode, 'statusCode', isNull),
      ),
    );
  });
}
