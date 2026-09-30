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
    when(() => storage.persistUser(any())).thenAnswer((_) async {});
    when(() => storage.readUser()).thenAnswer((_) async => null);
    when(() => storage.deleteUser()).thenAnswer((_) async {});
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

  group('entrada offline com o perfil salvo', () {
    const semRede = ApiException(
      message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
      isNetworkError: true,
    );

    void stubSavedTokens() {
      when(() => storage.readAccess()).thenAnswer((_) async => accessToken);
      when(() => storage.readRefresh()).thenAnswer((_) async => 'refresh-1');
    }

    test('login com "manter conectado" guarda o perfil no aparelho', () async {
      stubLogin(token: fakeJwt({'sub': 'user-1', 'consultantId': 'consultant-9'}));
      stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});

      await repository.login(email: 'c@s.com', password: '123456', keepSignedIn: true);

      final saved = verify(() => storage.persistUser(captureAny())).captured.single as String;
      final user = AuthUser.fromJson(jsonDecode(saved) as Map<String, dynamic>)!;
      expect(user.name, 'Carla');
      expect(user.role, AppUserRole.consultant);
      expect(user.consultantId, 'consultant-9');
    });

    test('sem "manter conectado", o perfil não vai para o aparelho', () async {
      stubLogin(token: fakeJwt({'sub': 'user-1'}));
      stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});

      await repository.login(email: 'c@s.com', password: '123456', keepSignedIn: false);

      verifyNever(() => storage.persistUser(any()));
    });

    test(
        'login apaga o perfil do login anterior antes de gravar os tokens '
        'novos', () async {
      stubLogin(token: fakeJwt({'sub': 'user-2'}));
      stubMe({'id': 'user-2', 'name': 'Bruno', 'email': 'b@s.com', 'role': 'CONSULTANT'});

      await repository.login(email: 'b@s.com', password: '123456', keepSignedIn: true);

      verifyInOrder([
        () => storage.deleteUser(),
        () => storage.persist(
              accessToken: any(named: 'accessToken'),
              refreshToken: any(named: 'refreshToken'),
            ),
        () => storage.persistUser(any()),
      ]);
    });

    test('falha ao gravar o perfil não impede o login', () async {
      stubLogin(token: fakeJwt({'sub': 'user-1'}));
      stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});
      when(() => storage.persistUser(any()))
          .thenThrow(PlatformException(code: 'keystore'));

      final result = await repository.login(
        email: 'c@s.com',
        password: '123456',
        keepSignedIn: true,
      );

      expect(result, isA<Success<AuthUser>>());
      expect(repository.isAuthenticated, isTrue);
    });

    test('falha ao gravar o perfil na abertura com rede não manda para o login',
        () async {
      stubSavedTokens();
      stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});
      when(() => storage.persistUser(any()))
          .thenThrow(PlatformException(code: 'keystore'));

      final result = await repository.restoreSession();

      expect(result, isA<Success<AuthUser>>());
      expect(repository.isAuthenticated, isTrue);
    });

    test(
        'sem rede na abertura, com sessão e perfil salvos, entra com o último '
        'perfil e mantém os tokens', () async {
      stubSavedTokens();
      when(() => api.get<Map<String, dynamic>>('/auth/me')).thenThrow(semRede);
      const salvo = AuthUser(
        id: 'user-1',
        name: 'Carla',
        email: 'c@s.com',
        role: AppUserRole.consultant,
        consultantId: 'consultant-9',
      );
      when(() => storage.readUser()).thenAnswer((_) async => jsonEncode(salvo.toJson()));

      final result = await repository.restoreSession();

      expect(result, isA<Success<AuthUser>>());
      expect(repository.isAuthenticated, isTrue);
      expect(repository.currentUser!.name, 'Carla');
      expect(repository.currentUser!.consultantId, 'consultant-9');
      verifyNever(() => storage.clear());
      expect(await session.readAccessToken(), accessToken,
          reason: 'quando a rede voltar, é este token que o servidor confere');
    });

    test('sem rede na abertura e sem perfil salvo, continua indo para o login',
        () async {
      stubSavedTokens();
      when(() => api.get<Map<String, dynamic>>('/auth/me')).thenThrow(semRede);

      final result = await repository.restoreSession();

      expect(result, isA<Failure<AuthUser>>());
      expect((result as Failure<AuthUser>).message, contains('Sem conexão'));
      expect(repository.isAuthenticated, isFalse);
    });

    test('401 na abertura encerra a sessão mesmo com perfil salvo', () async {
      stubSavedTokens();
      when(() => api.get<Map<String, dynamic>>('/auth/me')).thenThrow(
          const ApiException(message: 'Não autorizado', statusCode: 401));
      when(() => storage.readUser()).thenAnswer((_) async => jsonEncode(const AuthUser(
            id: 'user-1',
            name: 'Carla',
            email: 'c@s.com',
            role: AppUserRole.consultant,
          ).toJson()));

      final result = await repository.restoreSession();

      expect(result, isA<Failure<AuthUser>>());
      expect(repository.isAuthenticated, isFalse);
      verify(() => storage.clear()).called(1);
    });

    test('erro do servidor que não é falta de rede não entra offline', () async {
      stubSavedTokens();
      when(() => api.get<Map<String, dynamic>>('/auth/me')).thenThrow(
          const ApiException(message: 'Erro interno', statusCode: 500));
      when(() => storage.readUser()).thenAnswer((_) async => jsonEncode(const AuthUser(
            id: 'user-1',
            name: 'Carla',
            email: 'c@s.com',
            role: AppUserRole.consultant,
          ).toJson()));

      final result = await repository.restoreSession();

      expect(result, isA<Failure<AuthUser>>());
      expect(repository.isAuthenticated, isFalse);
    });

    test('perfil salvo ilegível não derruba a abertura: vai para o login', () async {
      stubSavedTokens();
      when(() => api.get<Map<String, dynamic>>('/auth/me')).thenThrow(semRede);
      when(() => storage.readUser()).thenAnswer((_) async => '{não é json');

      final result = await repository.restoreSession();

      expect(result, isA<Failure<AuthUser>>());
      expect(repository.isAuthenticated, isFalse);
    });

    test('abertura com rede atualiza o perfil salvo', () async {
      stubSavedTokens();
      stubMe({'id': 'user-1', 'name': 'Carla Mendes', 'email': 'c@s.com', 'role': 'CONSULTANT'});

      await repository.restoreSession();

      final saved = verify(() => storage.persistUser(captureAny())).captured.single as String;
      expect(AuthUser.fromJson(jsonDecode(saved) as Map<String, dynamic>)!.name, 'Carla Mendes');
    });
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
