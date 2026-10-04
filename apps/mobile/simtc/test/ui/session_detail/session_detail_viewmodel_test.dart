import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/session_detail/participant_filter.dart';
import 'package:simtc/ui/session_detail/session_detail_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockAssessmentRepository extends Mock implements AssessmentRepository {}

/// Conectividade de mentira: o serviço real conversa com o plugin de
/// plataforma, que não existe num teste de unidade.
class _FakeConnectivity extends ConnectivityService {
  final _reconnected = StreamController<void>.broadcast();

  @override
  Stream<void> get onReconnected => _reconnected.stream;

  void reconnect() => _reconnected.add(null);

  @override
  void dispose() {
    _reconnected.close();
    super.dispose();
  }
}

void main() {
  late _MockSessionRepository sessions;
  late _MockParticipantRepository participants;
  late _MockAssessmentRepository assessments;
  late _FakeConnectivity connectivity;
  late StreamController<TrainingSession?> sessionStream;
  late StreamController<List<SessionParticipant>> participantsStream;
  late StreamController<List<LocalAssessment>> localStream;

  const consultora = AuthUser(
    id: 'u1',
    name: 'Carla Souza',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-eu',
  );

  TrainingSession session({
    SessionStatus status = SessionStatus.emAndamento,
    String? responsible = 'c-resp',
    DateTime? participantsSyncedAt,
  }) {
    return TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell',
      courseName: 'Direção Defensiva',
      city: 'Itabira',
      state: 'MG',
      status: status,
      totalParticipants: 0,
      assessableParticipants: 0,
      assessedParticipants: 0,
      responsibleConsultantId: responsible,
      participantsSyncedAt: participantsSyncedAt ?? DateTime(2026, 9, 23, 8),
    );
  }

  SessionParticipant participant(
    String id, {
    ParticipantStatus status = ParticipantStatus.pendente,
    String? assignedTo,
    String? assessedBy,
  }) {
    return SessionParticipant(
      id: id,
      sessionId: 'sess-1',
      name: 'Participante $id',
      maskedCpf: '042.118.***-**',
      participationType: ParticipationType.teoricaEPratica,
      status: status,
      assignedConsultantId: assignedTo,
      assessedByConsultantId: assessedBy,
    );
  }

  /// Avaliação deste aparelho, do jeito que o `AssessmentRepository` guarda.
  LocalAssessment local(
    String participantId,
    LocalSyncStatus status, {
    DateTime? lastAttemptAt,
  }) {
    final at = DateTime(2026, 9, 23, 13);
    return LocalAssessment(
      id: 'local-$participantId',
      trainingParticipantId: participantId,
      sessionId: 'sess-1',
      date: DateTime(2026, 9, 23),
      startTime: at,
      syncStatus: status,
      attemptCount: 0,
      createdAt: at,
      updatedAt: at,
      ownerUserId: 'u1',
      lastAttemptAt: lastAttemptAt,
    );
  }

  SessionDetailViewModel build({AuthUser? user = consultora}) {
    return SessionDetailViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      assessmentRepository: assessments,
      connectivity: connectivity,
      currentUser: user,
      now: () => DateTime(2026, 9, 23, 14),
    );
  }

  /// Monta a VM já com a sessão e os participantes entregues pelo cache.
  Future<SessionDetailViewModel> ready({
    TrainingSession? withSession,
    List<SessionParticipant> withParticipants = const [],
    AuthUser? user = consultora,
  }) async {
    final vm = build(user: user)..init();
    sessionStream.add(withSession ?? session());
    participantsStream.add(withParticipants);
    await Future<void>.delayed(Duration.zero);
    return vm;
  }

  setUp(() {
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    assessments = _MockAssessmentRepository();
    connectivity = _FakeConnectivity();
    sessionStream = StreamController<TrainingSession?>.broadcast();
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();
    localStream = StreamController<List<LocalAssessment>>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
    when(() => assessments.watchSessionAssessments('sess-1', any()))
        .thenAnswer((_) => localStream.stream);
  });

  tearDown(() {
    sessionStream.close();
    participantsStream.close();
    localStream.close();
    connectivity.dispose();
  });

  test('baixa o detalhe ao abrir e de novo quando a conexão volta', () async {
    await ready();

    connectivity.reconnect();
    await Future<void>.delayed(Duration.zero);

    verify(() => participants.syncSession('sess-1')).called(2);
  });

  test('nunca baixada: fica carregando até a primeira descida terminar',
      () async {
    final download = Completer<Result<int>>();
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) => download.future);

    final vm = build()..init();
    sessionStream.add(const TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell',
      courseName: 'Direção Defensiva',
      city: 'Itabira',
      state: 'MG',
      status: SessionStatus.emAndamento,
      totalParticipants: 0,
      assessableParticipants: 0,
      assessedParticipants: 0,
    ));
    participantsStream.add(const []);
    await Future<void>.delayed(Duration.zero);

    expect(vm.isLoading, isTrue);

    download.complete(const Success(0));
    await Future<void>.delayed(Duration.zero);

    expect(vm.isLoading, isFalse);
    expect(vm.neverDownloaded, isTrue,
        reason: 'o stream da sessão ainda não trouxe participantsSyncedAt');
  });

  test('os chips filtram e os contadores não dependem do chip escolhido',
      () async {
    final vm = await ready(withParticipants: [
      participant('pend'),
      participant('meu', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu'),
      participant('ok', status: ParticipantStatus.aprovado, assessedBy: 'c-2'),
    ]);

    vm.setFilter(ParticipantFilter.meus);

    expect(vm.visibleParticipants.map((p) => p.id), ['meu']);
    expect(vm.counts[ParticipantFilter.todos], 3);
    expect(vm.counts[ParticipantFilter.pendentes], 1);
    expect(vm.counts[ParticipantFilter.concluidos], 1);
  });

  group('regras de ação', () {
    test('atribuir só com a sessão em andamento', () async {
      final emAndamento = await ready(withParticipants: [participant('p')]);
      expect(emAndamento.canAssign(participant('p')), isTrue);

      final planejada = await ready(
        withSession: session(status: SessionStatus.planejado),
        withParticipants: [participant('p')],
      );
      expect(planejada.canAssign(participant('p')), isFalse);
    });

    test('ADMIN sem perfil de consultor não atribui', () async {
      final vm = await ready(
        withParticipants: [participant('p')],
        user: const AuthUser(
          id: 'u2',
          name: 'Rita Alves',
          email: 'rita@simtc.com.br',
          role: AppUserRole.admin,
        ),
      );

      expect(vm.canAssign(participant('p')), isFalse);
      expect(vm.hasConsultantProfile, isFalse);
    });

    test('o checklist abre só para o meu participante, com a sessão aberta',
        () async {
      final meu =
          participant('meu', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final aberta = await ready(withParticipants: [meu]);
      expect(aberta.opensChecklist(meu), isTrue);

      final concluida = await ready(
        withSession: session(status: SessionStatus.concluido),
        withParticipants: [meu],
      );
      expect(concluida.opensChecklist(meu), isFalse);
    });

    test(
        'a linha "comigo" sabe se a avaliação deste aparelho é rascunho, está '
        'na fila ou falhou — e, confirmada, não abre mais o checklist',
        () async {
      final rascunho =
          participant('r', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final fila =
          participant('f', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final erro =
          participant('e', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final vm = await ready(withParticipants: [rascunho, fila, erro]);

      localStream.add([
        local('r', LocalSyncStatus.draft),
        local('f', LocalSyncStatus.pendingSync),
        local('e', LocalSyncStatus.error),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(vm.localProgressFor(rascunho), LocalProgress.draft);
      expect(vm.localProgressFor(fila), LocalProgress.queued);
      expect(vm.localProgressFor(erro), LocalProgress.failed);
      expect(vm.localAssessmentFor('f')?.id, 'local-f');
      expect(vm.opensChecklist(rascunho), isTrue);
      expect(vm.opensChecklist(fila), isFalse);
      expect(vm.opensChecklist(erro), isFalse);
      // Confirmada, a linha abre o Resultado, só para leitura (decisão de
      // 01/10/2026).
      expect(vm.opensResult(rascunho), isFalse);
      expect(vm.opensResult(fila), isTrue);
      expect(vm.opensResult(erro), isTrue);
    });

    test(
        'avaliação já enviada, ou numa linha que o servidor já não mostra '
        'comigo, não muda a linha', () async {
      final meu =
          participant('m', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final aprovado = participant('a', status: ParticipantStatus.aprovado);
      final vm = await ready(withParticipants: [meu, aprovado]);

      localStream.add([
        local('m', LocalSyncStatus.synced),
        local('a', LocalSyncStatus.pendingSync),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(vm.localProgressFor(meu), isNull);
      expect(vm.localProgressFor(aprovado), isNull);
      expect(vm.opensChecklist(meu), isTrue);
    });

    test('o resultado abre em qualquer status de sessão', () async {
      final ok = participant('ok', status: ParticipantStatus.aprovado);
      final vm = await ready(
        withSession: session(status: SessionStatus.concluido),
        withParticipants: [ok],
      );

      expect(vm.opensResult(ok), isTrue);
    });

    test('iniciar é do responsável e do ADMIN, e só com a sessão planejada',
        () async {
      final responsavel = await ready(
        withSession: session(status: SessionStatus.planejado, responsible: 'c-eu'),
      );
      expect(responsavel.canStartSession, isTrue);

      final outro = await ready(
        withSession: session(status: SessionStatus.planejado, responsible: 'c-2'),
      );
      expect(outro.canStartSession, isFalse);

      final admin = await ready(
        withSession: session(status: SessionStatus.planejado, responsible: 'c-2'),
        user: const AuthUser(
          id: 'u2',
          name: 'Rita Alves',
          email: 'rita@simtc.com.br',
          role: AppUserRole.admin,
        ),
      );
      expect(admin.canStartSession, isTrue);

      final jaIniciada = await ready(
        withSession: session(status: SessionStatus.emAndamento, responsible: 'c-eu'),
      );
      expect(jaIniciada.canStartSession, isFalse);
    });
  });

  group('linha "comigo" depois do envio aceito (revisão de 30/09/2026)', () {
    test(
        'sem download novo depois do envio, a linha mostra "Enviada" e não '
        'abre mais o checklist', () async {
      final meu =
          participant('m', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final vm = await ready(
        withSession: session(participantsSyncedAt: DateTime(2026, 9, 23, 8)),
        withParticipants: [meu],
      );

      localStream.add([
        local('m', LocalSyncStatus.synced, lastAttemptAt: DateTime(2026, 9, 23, 13)),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(vm.localProgressFor(meu), LocalProgress.sent);
      expect(vm.opensChecklist(meu), isFalse);
      expect(vm.opensResult(meu), isTrue);
    });

    test(
        'depois que a sessão é baixada de novo, a linha volta a valer o '
        'status do servidor', () async {
      final meu =
          participant('m', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final vm = await ready(
        withSession: session(participantsSyncedAt: DateTime(2026, 9, 23, 8)),
        withParticipants: [meu],
      );

      localStream.add([
        local('m', LocalSyncStatus.synced, lastAttemptAt: DateTime(2026, 9, 23, 13)),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(vm.localProgressFor(meu), LocalProgress.sent);

      // A sessão é regravada com um download posterior ao envio.
      sessionStream.add(session(participantsSyncedAt: DateTime(2026, 9, 23, 14)));
      await Future<void>.delayed(Duration.zero);

      expect(vm.localProgressFor(meu), isNull);
    });
  });

  group('assign', () {
    test('atribui com meu id e meu nome, avisa e baixa o detalhe de novo',
        () async {
      when(() => participants.assign('p1',
              consultantId: 'c-eu', consultantName: 'Carla Souza'))
          .thenAnswer((_) async => const Success<void>(null));
      final vm = await ready(withParticipants: [participant('p1')]);

      await vm.assign('p1');
      await Future<void>.delayed(Duration.zero);

      expect(vm.message, 'Participante atribuído a você.');
      expect(vm.assigningParticipantId, isNull);
      verify(() => participants.syncSession('sess-1')).called(2);
    });

    test('conflito mostra o motivo e baixa o detalhe para mostrar com quem está',
        () async {
      when(() => participants.assign('p1',
              consultantId: any(named: 'consultantId'),
              consultantName: any(named: 'consultantName')))
          .thenAnswer((_) async => const Failure<void>(
                ApiException(
                  message: 'Um ou mais participantes já estão em avaliação com outro consultor',
                  statusCode: 409,
                ),
                'Um ou mais participantes já estão em avaliação com outro consultor',
              ));
      final vm = await ready(withParticipants: [participant('p1')]);

      await vm.assign('p1');
      await Future<void>.delayed(Duration.zero);

      expect(vm.message,
          'Um ou mais participantes já estão em avaliação com outro consultor');
      verify(() => participants.syncSession('sess-1')).called(2);
    });

    test('sem rede, avisa e não tenta baixar de novo', () async {
      when(() => participants.assign('p1',
              consultantId: any(named: 'consultantId'),
              consultantName: any(named: 'consultantName')))
          .thenAnswer((_) async => const Failure<void>(
                ApiException(message: 'Sem conexão com o servidor.', isNetworkError: true),
                'Sem conexão com o servidor.',
              ));
      final vm = await ready(withParticipants: [participant('p1')]);

      await vm.assign('p1');
      await Future<void>.delayed(Duration.zero);

      expect(vm.message, 'Sem conexão com o servidor.');
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('um segundo toque enquanto o primeiro não voltou é ignorado', () async {
      final resposta = Completer<Result<void>>();
      when(() => participants.assign(any(),
              consultantId: any(named: 'consultantId'),
              consultantName: any(named: 'consultantName')))
          .thenAnswer((_) => resposta.future);
      final vm = await ready(
        withParticipants: [participant('p1'), participant('p2')],
      );

      final primeiro = vm.assign('p1');
      await vm.assign('p2');
      expect(vm.assigningParticipantId, 'p1');

      resposta.complete(const Success<void>(null));
      await primeiro;

      verify(() => participants.assign(any(),
          consultantId: any(named: 'consultantId'),
          consultantName: any(named: 'consultantName'))).called(1);
    });
  });

  group('startSession', () {
    test('inicia, avisa e baixa o detalhe de novo', () async {
      when(() => sessions.start('sess-1'))
          .thenAnswer((_) async => const Success<void>(null));
      final vm = await ready(
        withSession: session(status: SessionStatus.planejado, responsible: 'c-eu'),
      );

      await vm.startSession();
      await Future<void>.delayed(Duration.zero);

      expect(vm.message, 'Sessão iniciada. Já dá para atribuir participantes.');
      verify(() => participants.syncSession('sess-1')).called(2);
    });

    test('falha vira mensagem, sem novo download', () async {
      when(() => sessions.start('sess-1')).thenAnswer(
        (_) async => const Failure<void>(
          ApiException(message: 'Sem conexão com o servidor.', isNetworkError: true),
          'Sem conexão com o servidor.',
        ),
      );
      final vm = await ready(
        withSession: session(status: SessionStatus.planejado, responsible: 'c-eu'),
      );

      await vm.startSession();

      expect(vm.message, 'Sem conexão com o servidor.');
      expect(vm.isStarting, isFalse);
      verify(() => participants.syncSession('sess-1')).called(1);
    });
  });

  test('falha ao atualizar vira mensagem, sem apagar a lista', () async {
    when(() => participants.syncSession('sess-1')).thenAnswer(
      (_) async => Failure(Exception('sem rede'),
          'Não foi possível atualizar. Mostrando os dados já baixados.'),
    );

    final vm = await ready(withParticipants: [participant('p1')]);

    expect(vm.message, 'Não foi possível atualizar. Mostrando os dados já baixados.');
    expect(vm.visibleParticipants, hasLength(1));
  });

  group('proteções contra dispose e refresh em voo', () {
    test(
        'sync que só responde depois do dispose não notifica um ChangeNotifier morto',
        () async {
      final sync = Completer<Result<int>>();
      when(() => participants.syncSession('sess-1'))
          .thenAnswer((_) => sync.future);

      // init() dispara o primeiro refresh e fica esperando o cache.
      final vm = build()..init();
      await Future<void>.delayed(Duration.zero);

      vm.dispose();
      sync.complete(const Success(0));

      // Se o `finally` do refresh chamar notifyListeners sem guarda, o erro
      // "used after being disposed" escapa como erro assíncrono não tratado.
      await pumpEventQueue();
    });

    test(
        'atribuir que só responde depois do dispose não tenta baixar de novo',
        () async {
      final resposta = Completer<Result<void>>();
      when(() => participants.assign('p1',
              consultantId: any(named: 'consultantId'),
              consultantName: any(named: 'consultantName')))
          .thenAnswer((_) => resposta.future);
      final vm = await ready(withParticipants: [participant('p1')]);

      final assignFuture = vm.assign('p1');
      vm.dispose();
      resposta.complete(const Success<void>(null));
      await assignFuture;
      await pumpEventQueue();

      // Só o sync inicial do ready(): nenhum resync depois do dispose.
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test(
        'resync depois de atribuir não se perde quando um refresh já está em voo',
        () async {
      final primeiroSync = Completer<Result<int>>();
      when(() => participants.syncSession('sess-1'))
          .thenAnswer((_) => primeiroSync.future);
      when(() => participants.assign('p1',
              consultantId: any(named: 'consultantId'),
              consultantName: any(named: 'consultantName')))
          .thenAnswer((_) async => const Success<void>(null));

      // init() dispara o primeiro refresh, que fica pendente no cache.
      final vm = build()..init();
      sessionStream.add(session());
      participantsStream.add([participant('p1')]);
      await Future<void>.delayed(Duration.zero);

      // O assign termina e tenta um resync enquanto o 1º refresh ainda voa.
      await vm.assign('p1');
      await Future<void>.delayed(Duration.zero);

      primeiroSync.complete(const Success(0));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(() => participants.syncSession('sess-1')).called(2);
    });
  });
}
