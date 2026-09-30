import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/utils/result.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late AppDatabase db;
  late AssessmentRepository assessments;
  late _MockApiClient api;
  late _MockParticipantRepository participants;
  late _MockConnectivity plugin;
  late StreamController<List<ConnectivityResult>> network;
  late ConnectivityService connectivity;
  late ValueNotifier<String?> user;

  /// Cada envio que chegou ao "backend", com os itens do corpo.
  late List<List<Map<String, dynamic>>> sent;
  AssessmentSyncService? service;

  const semRede = ApiException(message: 'Sem conexão', isNetworkError: true);

  /// A resposta do `POST /practical-assessments/sync` real: 201, item a item.
  Response<List<dynamic>> reply(
    List<Map<String, dynamic>> payload,
    String? Function(String trainingParticipantId) errorFor,
  ) {
    return Response<List<dynamic>>(
      requestOptions: RequestOptions(path: AssessmentSyncService.syncPath),
      statusCode: 201,
      data: [
        for (final item in payload)
          {
            'trainingParticipantId': item['trainingParticipantId'],
            'status': errorFor(item['trainingParticipantId'] as String) == null
                ? 'fulfilled'
                : 'rejected',
            'error': errorFor(item['trainingParticipantId'] as String),
          },
      ],
    );
  }

  List<Map<String, dynamic>> payloadOf(Invocation invocation) =>
      (invocation.namedArguments[#data] as List).cast<Map<String, dynamic>>();

  void answer(String? Function(String trainingParticipantId) errorFor) {
    when(() => api.post<List<dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((invocation) async {
      final payload = payloadOf(invocation);
      sent.add(payload);
      return reply(payload, errorFor);
    });
  }

  void acceptAll() => answer((_) => null);

  void failWith(ApiException error) {
    when(() => api.post<List<dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((invocation) async {
      sent.add(payloadOf(invocation));
      throw error;
    });
  }

  Future<void> useConnectivity(ConnectivityResult result) async {
    when(plugin.checkConnectivity).thenAnswer((_) async => [result]);
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    assessments = AssessmentRepository(database: db);
    api = _MockApiClient();
    participants = _MockParticipantRepository();
    plugin = _MockConnectivity();
    network = StreamController<List<ConnectivityResult>>.broadcast();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => network.stream);
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
    user = ValueNotifier<String?>('user-1');
    sent = [];
    when(() => participants.syncSession(any()))
        .thenAnswer((_) async => const Success(0));
    acceptAll();
  });

  tearDown(() async {
    service?.dispose();
    service = null;
    user.dispose();
    connectivity.dispose();
    await network.close();
    await db.close();
  });

  AssessmentSyncService startService({
    List<Duration> retryDelays = const [Duration(hours: 1)],
  }) {
    final started = AssessmentSyncService(
      apiClient: api,
      assessments: assessments,
      participants: participants,
      connectivity: connectivity,
      authChanges: user,
      currentUserId: () => user.value,
      now: () => DateTime(2026, 9, 29, 9, 15),
      retryDelays: retryDelays,
    );
    service = started..start();
    return started;
  }

  /// O que o "Confirmar" da tela 1.6 deixa no banco.
  Future<LocalAssessment> confirmed(
    String participantId, {
    String owner = 'user-1',
  }) async {
    final draft = await assessments.openDraft(
      trainingParticipantId: participantId,
      sessionId: 'sess-1',
      ownerUserId: owner,
    );
    await assessments.confirm(draft.id, participantName: 'P $participantId', score: 90);
    return draft;
  }

  Future<LocalAssessment> row(String id) {
    return (db.select(db.localAssessments)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<LocalSyncStatus> statusOf(String id) async => (await row(id)).syncStatus;

  /// Espera o trabalho assíncrono do serviço (streams do drift, envio)
  /// cumprir [condition].
  Future<void> until(FutureOr<bool> Function() condition) async {
    for (var i = 0; i < 400; i++) {
      if (await condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('a condição não se cumpriu a tempo');
  }

  test('confirmar com rede envia sozinho, e a aceita sai da fila', () async {
    final sync = startService();

    final a = await confirmed('tp-1');

    await until(() async => await statusOf(a.id) == LocalSyncStatus.synced);
    expect(sent, hasLength(1));
    expect(sent.single.single['trainingParticipantId'], 'tp-1');
    await until(() => sync.queue.isEmpty);
    verify(() => participants.syncSession('sess-1')).called(1);
  });

  test(
      'ao entrar, sai o que já estava no aparelho — inclusive as avaliações '
      'sem dono, da Fase 4', () async {
    user.value = null;
    final mine = await confirmed('tp-1');
    final legacy = await confirmed('tp-2', owner: 'quem-for');
    await (db.update(db.localAssessments)..where((t) => t.id.equals(legacy.id)))
        .write(const LocalAssessmentsCompanion(ownerUserId: Value(null)));
    startService();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(sent, isEmpty, reason: 'ninguém logado, nada sai');

    user.value = 'user-1';

    await until(() async =>
        await statusOf(mine.id) == LocalSyncStatus.synced &&
        await statusOf(legacy.id) == LocalSyncStatus.synced);
    expect(sent.single.map((p) => p['trainingParticipantId']),
        unorderedEquals(['tp-1', 'tp-2']));
    expect((await row(legacy.id)).ownerUserId, 'user-1');
  });

  test('avaliação de outro consultor não sai no nome de quem está logado',
      () async {
    final theirs = await confirmed('tp-1', owner: 'user-2');
    final mine = await confirmed('tp-2');

    startService();

    await until(() async => await statusOf(mine.id) == LocalSyncStatus.synced);
    expect(sent.expand((batch) => batch).map((p) => p['trainingParticipantId']),
        ['tp-2']);
    expect(await statusOf(theirs.id), LocalSyncStatus.pendingSync);
  });

  test('o backend recusando um item deixa só ele na fila, com o motivo',
      () async {
    answer((id) => id == 'tp-2' ? 'Foreign key constraint violated' : null);
    final ok = await confirmed('tp-1');
    final refused = await confirmed('tp-2');

    final sync = startService();

    await until(() async => await statusOf(refused.id) == LocalSyncStatus.error);
    expect(await statusOf(ok.id), LocalSyncStatus.synced);
    expect((await row(refused.id)).lastError, SendFailure.refused);
    await until(() => sync.queue.length == 1);
    expect(sync.queue.single.id, refused.id);
  });

  test(
      'sem rede, não tenta: a fila fica "Na fila" e sai sozinha quando a rede '
      'volta', () async {
    await useConnectivity(ConnectivityResult.none);
    final sync = startService();

    final a = await confirmed('tp-1');
    await until(() => sync.queue.length == 1);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(sent, isEmpty);
    expect(await statusOf(a.id), LocalSyncStatus.pendingSync);

    network.add([ConnectivityResult.wifi]);

    await until(() async => await statusOf(a.id) == LocalSyncStatus.synced);
  });

  test(
      'falha de rede marca a fila com o motivo e tenta de novo sozinha, '
      'depois da espera', () async {
    failWith(semRede);
    startService(retryDelays: const [Duration(milliseconds: 50)]);

    final a = await confirmed('tp-1');
    await until(() async => await statusOf(a.id) == LocalSyncStatus.error);
    expect((await row(a.id)).lastError, SendFailure.noConnection);

    acceptAll();

    await until(() async => await statusOf(a.id) == LocalSyncStatus.synced);
    expect(sent, hasLength(2));
  });

  test('cada tipo de falha tem o seu motivo', () async {
    startService();
    final cases = [
      (
        const ApiException(message: 'x', isNetworkError: true, isTimeout: true),
        SendFailure.timeout,
      ),
      (const ApiException(message: 'x', statusCode: 503), SendFailure.serverDown),
      (
        const ApiException(message: 'Consultor não identificado', statusCode: 409),
        SendFailure.refused,
      ),
    ];

    for (var i = 0; i < cases.length; i++) {
      final (error, reason) = cases[i];
      failWith(error);
      final a = await confirmed('tp-$i');
      await until(() async => await statusOf(a.id) == LocalSyncStatus.error);
      expect((await row(a.id)).lastError, reason, reason: '$error');
    }
  });

  test(
      '401 no envio (sessão encerrada) não marca erro: a fila espera o dono '
      'entrar de novo', () async {
    failWith(const ApiException(message: 'Unauthorized', statusCode: 401));
    startService();

    final a = await confirmed('tp-1');
    await until(() => sent.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(await statusOf(a.id), LocalSyncStatus.pendingSync);
    expect((await row(a.id)).lastError, isNull);
  });

  test('"Sincronizar agora" não espera a próxima tentativa', () async {
    failWith(semRede);
    final sync = startService(retryDelays: const [Duration(hours: 1)]);
    final a = await confirmed('tp-1');
    await until(() async => await statusOf(a.id) == LocalSyncStatus.error);
    acceptAll();

    await sync.syncNow();

    expect(await statusOf(a.id), LocalSyncStatus.synced);
  });

  test(
      'avaliação que ficou em erro numa execução anterior sai sozinha ao '
      'entrar de novo', () async {
    final a = await confirmed('tp-1');
    await assessments.saveSendResults(
      {a.id: SendFailure.noConnection},
      at: DateTime(2026, 9, 29, 8),
    );
    expect(await statusOf(a.id), LocalSyncStatus.error);

    startService();

    await until(() async => await statusOf(a.id) == LocalSyncStatus.synced);
    expect(sent, hasLength(1));
  });

  test(
      'um envio por vez: o que entra no meio do envio sai num segundo envio, '
      'logo depois', () async {
    final gate = Completer<void>();
    when(() => api.post<List<dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((invocation) async {
      final payload = payloadOf(invocation);
      sent.add(payload);
      if (sent.length == 1) await gate.future;
      return reply(payload, (_) => null);
    });
    final sync = startService();

    final first = await confirmed('tp-1');
    await until(() => sent.length == 1);
    expect(sync.isSending, isTrue);
    expect(sync.isSendingItem(first.id), isTrue);

    final second = await confirmed('tp-2');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(sent, hasLength(1), reason: 'o segundo espera o primeiro terminar');
    expect(sync.isSendingItem(second.id), isFalse);

    gate.complete();

    await until(() async => await statusOf(second.id) == LocalSyncStatus.synced);
    expect(sent, hasLength(2));
    expect(sent[1].map((p) => p['trainingParticipantId']), ['tp-2']);
    await until(() => !sync.isSending);
  });

  test('mostra à tela a última sincronização aceita', () async {
    final sync = startService();
    expect(sync.lastSyncedAt, isNull);

    await confirmed('tp-1');

    await until(() => sync.lastSyncedAt != null);
    expect(sync.lastSyncedAt, DateTime(2026, 9, 29, 9, 15));
    expect(sync.queue, isEmpty);
  });

  test('sair da conta para de seguir a fila de quem saiu', () async {
    failWith(semRede);
    final sync = startService();
    await confirmed('tp-1');
    await until(() => sync.queue.length == 1);

    user.value = null;

    expect(sync.queue, isEmpty);
    expect(sync.lastSyncedAt, isNull);
  });

  group('download de pós-envio que falha (revisão de 30/09/2026)', () {
    /// Controla, uma a uma, as respostas do `syncSession` mockado — para
    /// separar cada tentativa de download sem depender de tempo real.
    List<Completer<Result<int>>> gateDownloads() {
      final calls = <Completer<Result<int>>>[];
      when(() => participants.syncSession('sess-1')).thenAnswer((_) {
        final completer = Completer<Result<int>>();
        calls.add(completer);
        return completer.future;
      });
      return calls;
    }

    test(
        'falhando, o download é tentado de novo no próximo syncNow, mesmo com '
        'a fila vazia', () async {
      final calls = gateDownloads();
      final sync = startService();

      final a = await confirmed('tp-1');
      await until(() async => await statusOf(a.id) == LocalSyncStatus.synced);
      await until(() => calls.length == 1);
      calls[0].complete(Failure(Exception('sem rede'), 'sem rede'));
      await until(() => sync.queue.isEmpty);

      await sync.syncNow();
      await until(() => calls.length == 2);

      calls[1].complete(const Success(1));
      await Future<void>.delayed(Duration.zero);

      verify(() => participants.syncSession('sess-1')).called(2);
    });

    test(
        'sessão aceita de novo durante o download em voo é baixada de novo '
        'sozinha, sem dois downloads ao mesmo tempo', () async {
      final calls = <Completer<Result<int>>>[];
      var inFlight = 0;
      var maxInFlight = 0;
      when(() => participants.syncSession('sess-1')).thenAnswer((_) {
        final completer = Completer<Result<int>>();
        calls.add(completer);
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        return completer.future.whenComplete(() => inFlight--);
      });
      startService();

      final a = await confirmed('tp-1');
      await until(() async => await statusOf(a.id) == LocalSyncStatus.synced);
      await until(() => calls.length == 1);

      // Com o primeiro download em voo, outro participante da mesma sessão é
      // confirmado e aceito.
      final b = await confirmed('tp-2');
      await until(() async => await statusOf(b.id) == LocalSyncStatus.synced);
      expect(calls, hasLength(1), reason: 'a sessão já está sendo baixada');

      calls[0].complete(const Success(1));

      await until(() => calls.length == 2);
      calls[1].complete(const Success(1));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(calls, hasLength(2), reason: 'sem laço de retentativa');
      expect(maxInFlight, 1);
    });

    test('um download bem-sucedido não é repetido no gatilho seguinte', () async {
      final sync = startService();

      final a = await confirmed('tp-1');
      await until(() async => await statusOf(a.id) == LocalSyncStatus.synced);
      await until(() => sync.queue.isEmpty);
      // Dá tempo do download de pós-envio (unawaited) terminar sozinho.
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sync.syncNow();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('trocar de usuário esquece as sessões que esperavam novo download',
        () async {
      final calls = gateDownloads();
      final sync = startService();

      final a = await confirmed('tp-1');
      await until(() async => await statusOf(a.id) == LocalSyncStatus.synced);
      await until(() => calls.length == 1);
      calls[0].complete(Failure(Exception('sem rede'), 'sem rede'));
      await until(() => sync.queue.isEmpty);

      user.value = null;
      user.value = 'user-1';
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sync.syncNow();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(calls, hasLength(1),
          reason: 'trocar de usuário esqueceu a sessão pendente');
    });
  });
}
