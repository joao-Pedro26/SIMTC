import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/auth_session.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/data/services/local/token_storage.dart';
import 'package:simtc/utils/result.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockTokenStorage extends Mock implements TokenStorage {}

/// JWT de teste: só o payload importa (a assinatura não é verificada no app).
String fakeJwt(Map<String, dynamic> payload) {
  String encode(Map<String, dynamic> part) =>
      base64Url.encode(utf8.encode(jsonEncode(part))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode(payload)}.assinatura';
}

Response<Map<String, dynamic>> jsonResponse(
  String path,
  Map<String, dynamic> body, {
  int status = 200,
}) {
  return Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: body,
  );
}

void main() {
  late _MockApiClient api;
  late _MockTokenStorage storage;
  late AuthSession session;
  late AppDatabase db;
  late AuthRepository repository;

  const accessToken = 'cabecalho.payload.assinatura';

  setUp(() {
    api = _MockApiClient();
    storage = _MockTokenStorage();
    session = AuthSession(storage);
    db = AppDatabase(NativeDatabase.memory());
    repository = AuthRepository(
      apiClient: api,
      session: session,
      clearLocalCache: db.clearSessionsCache,
    );

    when(() => storage.persist(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async {});
    when(() => storage.clear()).thenAnswer((_) async {});
    when(() => storage.setKeepSignedIn(any())).thenAnswer((_) async {});
    when(() => storage.readKeepSignedIn()).thenAnswer((_) async => true);
    when(() => storage.readAccess()).thenAnswer((_) async => null);
    when(() => storage.readRefresh()).thenAnswer((_) async => null);
  });

  tearDown(() async {
    session.dispose();
    await db.close();
  });

  Future<void> seedCache() async {
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-antigo-consultor',
            companyName: 'Bracell Celulose',
            courseName: 'Direção Preventiva',
            city: 'Lençóis Paulista',
            state: 'SP',
            status: 'PLANEJADO',
            cachedAt: DateTime(2026, 9, 17, 8),
          ),
        );
    await db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-1',
            sessionId: 'sess-antigo-consultor',
            name: 'João Pedro',
            cpf: '12345678909',
            participationType: 'TEORICA_E_PRATICA',
            status: 'PENDENTE',
            cachedAt: DateTime(2026, 9, 17, 8),
          ),
        );
  }

  void stubLogin({required String token}) {
    when(() => api.post<Map<String, dynamic>>('/auth/login', data: any(named: 'data')))
        .thenAnswer((_) async => jsonResponse(
              '/auth/login',
              {'accessToken': token, 'refreshToken': 'refresh-1'},
            ));
  }

  void stubMe(Map<String, dynamic> body) {
    when(() => api.get<Map<String, dynamic>>('/auth/me'))
        .thenAnswer((_) async => jsonResponse('/auth/me', body));
  }

  test('login guarda a sessão e traz o consultantId do JWT', () async {
    final token = fakeJwt({'sub': 'user-1', 'consultantId': 'consultant-9'});
    stubLogin(token: token);
    stubMe({
      'id': 'user-1',
      'name': 'Carla Mendes',
      'email': 'carla@simtc.com.br',
      'role': 'CONSULTANT',
    });

    final result = await repository.login(
      email: ' carla@simtc.com.br ',
      password: 'segredo 123',
      keepSignedIn: true,
    );

    expect(result, isA<Success<AuthUser>>());
    final user = (result as Success<AuthUser>).data;
    expect(user.name, 'Carla Mendes');
    expect(user.role, AppUserRole.consultant);
    expect(user.consultantId, 'consultant-9');
    expect(repository.isAuthenticated, isTrue);

    final sent = verify(() => api.post<Map<String, dynamic>>('/auth/login',
        data: captureAny(named: 'data'))).captured.single as Map<String, dynamic>;
    expect(sent['email'], 'carla@simtc.com.br', reason: 'e-mail é aparado');
    expect(sent['password'], 'segredo 123', reason: 'a senha não pode ser aparada');

    verify(() => storage.persist(
          accessToken: token,
          refreshToken: 'refresh-1',
        )).called(1);
  });

  test('sem "manter conectado", os tokens não vão para o armazenamento', () async {
    stubLogin(token: fakeJwt({'sub': 'user-1'}));
    stubMe({'id': 'user-1', 'name': 'Admin', 'email': 'a@b.com', 'role': 'ADMIN'});

    await repository.login(
      email: 'a@b.com',
      password: '123456',
      keepSignedIn: false,
    );

    verifyNever(() => storage.persist(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ));
    expect(await session.readAccessToken(), isNotNull,
        reason: 'a sessão continua válida enquanto o app estiver aberto');
  });

  test('perfil CLIENT é recusado com mensagem própria', () async {
    stubLogin(token: fakeJwt({'sub': 'user-2'}));
    stubMe({'id': 'user-2', 'name': 'Cliente', 'email': 'c@b.com', 'role': 'CLIENT'});
    when(() => api.post<void>('/auth/logout'))
        .thenAnswer((_) async => Response<void>(requestOptions: RequestOptions(path: '/auth/logout')));

    final result = await repository.login(
      email: 'c@b.com',
      password: '123456',
      keepSignedIn: true,
    );

    expect(result, isA<Failure<AuthUser>>());
    expect((result as Failure<AuthUser>).message, contains('portal web'));
    expect(repository.isAuthenticated, isFalse);
  });

  test('401 no login vira mensagem de credencial incorreta', () async {
    when(() => api.post<Map<String, dynamic>>('/auth/login', data: any(named: 'data')))
        .thenThrow(const ApiException(message: 'Credenciais inválidas', statusCode: 401));

    final result = await repository.login(
      email: 'x@y.com',
      password: 'errada',
      keepSignedIn: true,
    );

    expect((result as Failure<AuthUser>).message, 'E-mail ou senha incorretos.');
  });

  test('falta de rede no login preserva a mensagem de conexão', () async {
    when(() => api.post<Map<String, dynamic>>('/auth/login', data: any(named: 'data')))
        .thenThrow(const ApiException(
      message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
      isNetworkError: true,
    ));

    final result = await repository.login(
      email: 'x@y.com',
      password: '123456',
      keepSignedIn: true,
    );

    expect((result as Failure<AuthUser>).message, contains('Sem conexão'));
  });

  test('restoreSession não trava quando o armazenamento seguro falha', () async {
    // Cenário real: a keystore do Android é invalidada quando o aparelho
    // restaura um backup ou o usuário troca o bloqueio de tela. Sem tratamento,
    // a exceção sobe até a tela de abertura e o app fica parado nela.
    when(() => storage.readAccess())
        .thenThrow(PlatformException(code: 'storage_error'));

    final result = await repository.restoreSession();

    expect(result, isA<Failure<AuthUser>>());
    expect((result as Failure<AuthUser>).message, contains('sessão'));
    verifyNever(() => api.get<Map<String, dynamic>>('/auth/me'));
  });

  test('restoreSession sem tokens salvos falha sem chamar a API', () async {
    final result = await repository.restoreSession();

    expect(result, isA<Failure<AuthUser>>());
    verifyNever(() => api.get<Map<String, dynamic>>('/auth/me'));
  });

  test('restoreSession com tokens salvos recupera o usuário', () async {
    when(() => storage.readAccess()).thenAnswer((_) async => accessToken);
    when(() => storage.readRefresh()).thenAnswer((_) async => 'refresh-1');
    stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});

    final result = await repository.restoreSession();

    expect(result, isA<Success<AuthUser>>());
    expect(repository.currentUser!.name, 'Carla');
  });

  test('logout limpa a sessão mesmo se a API falhar', () async {
    stubLogin(token: fakeJwt({'sub': 'user-1'}));
    stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});
    await repository.login(email: 'c@s.com', password: '123456', keepSignedIn: true);

    when(() => api.post<void>('/auth/logout'))
        .thenThrow(const ApiException(message: 'offline', isNetworkError: true));

    await repository.logout();

    expect(repository.isAuthenticated, isFalse);
    expect(await session.readAccessToken(), isNull);
    verify(() => storage.clear()).called(greaterThanOrEqualTo(1));
  });

  test(
      'logout apaga o cache de sessões — senão o próximo consultor a entrar '
      'herda a agenda do anterior enquanto offline', () async {
    await seedCache();
    when(() => api.post<void>('/auth/logout')).thenAnswer(
        (_) async => Response<void>(requestOptions: RequestOptions(path: '/auth/logout')));

    await repository.logout();

    expect(await db.select(db.sessions).get(), isEmpty);
    expect(await db.select(db.participants).get(), isEmpty);
  });

  test(
      'handleSessionExpired apaga o cache de sessões — é o caminho real '
      'quando o refresh token expira e outro consultor entra depois',
      () async {
    stubLogin(token: fakeJwt({'sub': 'user-1'}));
    stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});
    await repository.login(email: 'c@s.com', password: '123456', keepSignedIn: true);
    await seedCache();

    await repository.handleSessionExpired();

    expect(repository.isAuthenticated, isFalse);
    expect(await db.select(db.sessions).get(), isEmpty);
    expect(await db.select(db.participants).get(), isEmpty);
  });

  test('esqueci a senha chama o endpoint e trata a resposta vazia', () async {
    when(() => api.post<void>('/auth/forgot-password', data: any(named: 'data')))
        .thenAnswer((_) async =>
            Response<void>(requestOptions: RequestOptions(path: '/auth/forgot-password'), statusCode: 204));

    final result = await repository.requestPasswordReset(' carla@simtc.com.br ');

    expect(result, isA<Success<void>>());
    final sent = verify(() => api.post<void>('/auth/forgot-password',
        data: captureAny(named: 'data'))).captured.single as Map<String, dynamic>;
    expect(sent['email'], 'carla@simtc.com.br');
  });
}
