import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/session_consultant.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/session_consultants/session_consultants_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockConsultantRepository extends Mock
    implements SessionConsultantRepository {}

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
  late _MockConsultantRepository consultants;
  late _FakeConnectivity connectivity;
  late StreamController<TrainingSession?> sessionStream;
  late StreamController<List<SessionParticipant>> participantsStream;
  late StreamController<List<SessionConsultant>> consultantsStream;

  const admin = AuthUser(
    id: 'u-admin',
    name: 'Carla Mendes',
    email: 'carla@sim.com',
    role: AppUserRole.admin,
    consultantId: 'c-carla',
  );
  const consultora = AuthUser(
    id: 'u1',
    name: 'Rafael Lima',
    email: 'rafael@sim.com',
    role: AppUserRole.consultant,
    consultantId: 'c-rafael',
  );

  const carla = SessionConsultant(id: 'c-carla', name: 'Carla Mendes');
  const rafael = SessionConsultant(id: 'c-rafael', name: 'Rafael Lima');
  const tatiane = SessionConsultant(id: 'c-tatiane', name: 'Tatiane Souza');
  const diego = SessionConsultant(
    id: 'c-diego',
    name: 'Diego Barbosa',
    email: 'diego@sim.com',
  );
  const patricia = SessionConsultant(id: 'c-patricia', name: 'Patrícia Vaz');

  const offlineError = ApiException(
    message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
    isNetworkError: true,
  );

  TrainingSession session({
    SessionStatus status = SessionStatus.emAndamento,
    String? responsible = 'c-carla',
    int total = 5,
    bool withoutDate = false,
  }) {
    return TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell',
      courseName: 'Direção Defensiva',
      city: 'Itabira',
      state: 'MG',
      date: withoutDate ? null : DateTime(2026, 9, 12),
      status: status,
      totalParticipants: total,
      assessableParticipants: total,
      assessedParticipants: 0,
      responsibleConsultantId: responsible,
      participantsSyncedAt: DateTime(2026, 9, 12, 8),
    );
  }

  SessionParticipant participant(
    String name, {
    ParticipantStatus status = ParticipantStatus.pendente,
    String? assignedTo,
    String? assessedBy,
    double? score,
    ParticipationType type = ParticipationType.teoricaEPratica,
  }) {
    return SessionParticipant(
      id: 'tp-$name',
      sessionId: 'sess-1',
      name: name,
      maskedCpf: '042.118.***-**',
      participationType: type,
      status: status,
      assignedConsultantId: assignedTo,
      assessedByConsultantId: assessedBy,
      score: score,
    );
  }

  SessionParticipant evaluating(String name, String consultantId, {double? score}) {
    return participant(
      name,
      status: ParticipantStatus.emAvaliacao,
      assignedTo: consultantId,
      score: score,
    );
  }

  SessionParticipant approved(String name, String consultantId) {
    return participant(
      name,
      status: ParticipantStatus.aprovado,
      assessedBy: consultantId,
      score: 90,
    );
  }

  setUp(() {
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    consultants = _MockConsultantRepository();
    connectivity = _FakeConnectivity();
    sessionStream = StreamController<TrainingSession?>.broadcast();
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();
    consultantsStream = StreamController<List<SessionConsultant>>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => consultants.watchBySession('sess-1'))
        .thenAnswer((_) => consultantsStream.stream);
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
    when(() => consultants.fetchTeam()).thenAnswer(
      (_) async => const Success([carla, diego, patricia, rafael, tatiane]),
    );
    when(() => consultants.add('sess-1', any()))
        .thenAnswer((_) async => const Success<void>(null));
    when(() => consultants.remove('sess-1', any()))
        .thenAnswer((_) async => const Success<void>(null));
  });

  tearDown(() {
    sessionStream.close();
    participantsStream.close();
    consultantsStream.close();
    connectivity.dispose();
  });

  SessionConsultantsViewModel build({AuthUser? user = admin}) {
    final vm = SessionConsultantsViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      consultantRepository: consultants,
      connectivity: connectivity,
      currentUser: user,
    )..init();
    addTearDown(vm.dispose);
    return vm;
  }

  /// A tela aberta, com o cache lido e a equipe já carregada.
  Future<SessionConsultantsViewModel> open({
    AuthUser? user = admin,
    TrainingSession? withSession,
    bool missing = false,
    List<SessionConsultant> inSession = const [carla, rafael, tatiane],
    List<SessionParticipant> people = const [],
  }) async {
    final vm = build(user: user);
    sessionStream.add(missing ? null : (withSession ?? session()));
    consultantsStream.add(inSession);
    participantsStream.add(people);
    await pumpEventQueue();
    return vm;
  }

  group('abertura', () {
    test('antes da primeira leitura do cache, está carregando', () {
      final vm = build();

      expect(vm.isLoading, isTrue);
      expect(vm.canChange, isFalse);
      // Carregando não é "ainda não baixados".
      expect(vm.notDownloaded, isFalse);
    });

    test('busca a equipe e baixa a sessão de novo', () async {
      final vm = await open();

      expect(vm.isLoading, isFalse);
      verify(() => consultants.fetchTeam()).called(1);
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('o contexto diz a empresa, a data e quanta gente tem', () async {
      final vm = await open();

      expect(vm.contextTitle, 'Bracell · 12 set');
      expect(vm.contextSubtitle, '5 participantes · 3 consultores');
    });

    test('o contexto no singular, e sem data', () async {
      final vm = await open(
        withSession: session(total: 1, withoutDate: true),
        inSession: const [carla],
      );

      expect(vm.contextTitle, 'Bracell');
      expect(vm.contextSubtitle, '1 participante · 1 consultor');
    });

    test('sem os consultores no aparelho, o contexto só conta os participantes, '
        'e a tela diz que ainda não foram baixados', () async {
      final vm = await open(inSession: const []);

      expect(vm.contextSubtitle, '5 participantes');
      expect(vm.inSession, isEmpty);
      expect(vm.notDownloaded, isTrue);
    });

    test('com os consultores no aparelho, não há o que baixar', () async {
      final vm = await open();

      expect(vm.notDownloaded, isFalse);
    });
  });

  group('na sessão', () {
    test('o responsável vem primeiro, e os outros por nome, sem o acento '
        'mandar para o fim', () async {
      const angela = SessionConsultant(id: 'c-angela', name: 'Ângela Reis');
      final vm = await open(
        withSession: session(responsible: 'c-rafael'),
        inSession: const [carla, rafael, tatiane, angela],
      );

      expect(
        vm.inSession.map((c) => c.name),
        ['Rafael Lima', 'Ângela Reis', 'Carla Mendes', 'Tatiane Souza'],
      );
      expect(vm.inSession.first.isResponsible, isTrue);
      expect(vm.inSession.skip(1).map((c) => c.isResponsible), everyElement(isFalse));
    });

    test('o consultor do usuário logado leva "(você)"; os outros, não',
        () async {
      final vm = await open();

      expect(
        vm.inSession.map((c) => c.displayName),
        ['Carla Mendes (você)', 'Rafael Lima', 'Tatiane Souza'],
      );
    });

    test('a linha de apoio conta os participantes de cada um neste aparelho',
        () async {
      final vm = await open(
        people: [
          evaluating('Ana Paula', 'c-carla'),
          approved('Bruno Dias', 'c-carla'),
          evaluating('Marcos Vinícius', 'c-rafael'),
          approved('Juliana Costa', 'c-tatiane'),
          approved('Rodrigo Tavares', 'c-tatiane'),
          // Ninguém pegou, e quem só faz a teórica: não são de consultor nenhum.
          participant('Sem Dono'),
          participant('Só Teórica', type: ParticipationType.somenteTeorica),
        ],
      );

      expect(vm.inSession.map((c) => c.meta), [
        '2 participantes · 1 em andamento',
        '1 participante · 1 em andamento',
        '2 participantes concluídos',
      ]);
      expect(vm.inSession.map((c) => c.inProgressCount), [1, 1, 0]);
    });

    test('um só concluído vai no singular, e quem não tem ninguém diz isso',
        () async {
      final vm = await open(people: [approved('Bruno Dias', 'c-rafael')]);

      expect(vm.inSession.map((c) => c.meta), [
        'Sem participantes',
        '1 participante concluído',
        'Sem participantes',
      ]);
    });

    test('o responsável não sai; os outros podem sair', () async {
      final vm = await open();

      expect(vm.inSession.map((c) => c.removable), [false, true, true]);
    });

    test('com uma avaliação em andamento, o aviso diz quem volta para Pendente',
        () async {
      final vm = await open(people: [evaluating('Marcos Vinícius', 'c-rafael')]);

      expect(
        vm.inSession[1].note,
        'Tem 1 avaliação em andamento. Remover devolve Marcos Vinícius para '
        'Pendente.',
      );
      expect(vm.inSession[2].note, isNull);
    });

    test('numa reavaliação, o participante volta para Não recomendado',
        () async {
      final vm = await open(
        people: [evaluating('Marcos Vinícius', 'c-rafael', score: 62)],
      );

      expect(
        vm.inSession[1].note,
        'Tem 1 avaliação em andamento. Remover devolve Marcos Vinícius para '
        'Não recomendado.',
      );
    });

    test('com duas ou mais, o aviso fala de todos', () async {
      final vm = await open(
        people: [
          evaluating('Marcos Vinícius', 'c-rafael'),
          evaluating('Ana Paula', 'c-rafael'),
        ],
      );

      expect(
        vm.inSession[1].note,
        'Tem 2 avaliações em andamento. Remover libera esses participantes '
        'para outro consultor.',
      );
    });

    test('o responsável não tem aviso, mesmo com avaliação em andamento',
        () async {
      final vm = await open(people: [evaluating('Ana Paula', 'c-carla')]);

      expect(vm.inSession.first.note, isNull);
      expect(vm.inSession.first.inProgressCount, 1);
    });
  });

  group('equipe', () {
    test('mostra quem é da equipe e ainda não está na sessão, por nome',
        () async {
      final vm = await open();

      expect(vm.available, const [diego, patricia]);
      expect(vm.teamNotice, isNull);
      expect(vm.isTeamLoading, isFalse);
    });

    test('a equipe fica por nome, sem depender da ordem do servidor nem do '
        'acento', () async {
      const angela = SessionConsultant(id: 'c-angela', name: 'Ângela Reis');
      when(() => consultants.fetchTeam())
          .thenAnswer((_) async => const Success([patricia, diego, angela]));
      final vm = await open();

      expect(vm.available, const [angela, diego, patricia]);
    });

    test('enquanto a equipe não chega, está carregando, sem aviso', () async {
      final answer = Completer<Result<List<SessionConsultant>>>();
      when(() => consultants.fetchTeam()).thenAnswer((_) => answer.future);
      final vm = await open();

      expect(vm.isTeamLoading, isTrue);
      expect(vm.available, isEmpty);
      expect(vm.teamNotice, isNull);

      answer.complete(const Success([diego]));
      await pumpEventQueue();

      expect(vm.isTeamLoading, isFalse);
      expect(vm.available, const [diego]);
    });

    test('quem entra na sessão sai da lista da equipe', () async {
      final vm = await open();

      consultantsStream.add(const [carla, rafael, tatiane, diego]);
      await pumpEventQueue();

      expect(vm.available, const [patricia]);
    });

    test('com todos já na sessão, a tela diz isso', () async {
      when(() => consultants.fetchTeam())
          .thenAnswer((_) async => const Success([carla, rafael]));
      final vm = await open();

      expect(vm.available, isEmpty);
      expect(
        vm.teamNotice,
        'Todos os consultores ativos da equipe já estão nesta sessão.',
      );
    });

    test('sem rede, a equipe fica para quando houver conexão — e carrega '
        'sozinha quando a rede volta', () async {
      when(() => consultants.fetchTeam())
          .thenAnswer((_) async => const Failure(offlineError, 'sem rede'));
      final vm = await open();

      expect(vm.available, isEmpty);
      expect(vm.teamNotice, 'A equipe aparece quando houver conexão.');

      when(() => consultants.fetchTeam())
          .thenAnswer((_) async => const Success([diego]));
      connectivity.reconnect();
      await pumpEventQueue();

      expect(vm.available, const [diego]);
      expect(vm.teamNotice, isNull);
      // A volta da rede também baixa a sessão de novo.
      verify(() => participants.syncSession('sess-1')).called(2);
    });

    test('outra falha pede para puxar, e atualizar carrega a equipe', () async {
      when(() => consultants.fetchTeam()).thenAnswer(
        (_) async => const Failure(
          ApiException(message: 'Internal server error', statusCode: 500),
          'Não foi possível carregar a equipe.',
        ),
      );
      final vm = await open();

      expect(
        vm.teamNotice,
        'Não foi possível carregar a equipe. Puxe para atualizar.',
      );

      when(() => consultants.fetchTeam())
          .thenAnswer((_) async => const Success([diego]));
      await vm.refresh();

      expect(vm.available, const [diego]);
      expect(vm.teamNotice, isNull);
    });

    test('uma exceção ao buscar a equipe não trava a tela', () async {
      when(() => consultants.fetchTeam()).thenThrow(StateError('quebrou'));
      final vm = await open();

      expect(vm.isTeamLoading, isFalse);
      expect(
        vm.teamNotice,
        'Não foi possível carregar a equipe. Puxe para atualizar.',
      );
    });

    test('uma falha ao atualizar não apaga a equipe que já estava na tela',
        () async {
      final vm = await open();

      when(() => consultants.fetchTeam())
          .thenAnswer((_) async => const Failure(offlineError, 'sem rede'));
      await vm.refresh();

      expect(vm.available, const [diego, patricia]);
      expect(vm.teamNotice, isNull);
    });

    test('ao atualizar com a equipe já na tela, a lista continua — não volta '
        'para o carregando', () async {
      final vm = await open();
      final answer = Completer<Result<List<SessionConsultant>>>();
      when(() => consultants.fetchTeam()).thenAnswer((_) => answer.future);

      final refreshing = vm.refresh();
      await pumpEventQueue();

      expect(vm.isTeamLoading, isFalse);
      expect(vm.available, const [diego, patricia]);

      answer.complete(const Success([diego]));
      await refreshing;
      expect(vm.available, const [diego]);
    });

    test('a volta da rede no meio de uma busca não dispara outra por cima',
        () async {
      final answer = Completer<Result<List<SessionConsultant>>>();
      when(() => consultants.fetchTeam()).thenAnswer((_) => answer.future);
      final vm = await open();

      connectivity.reconnect();
      await pumpEventQueue();

      verify(() => consultants.fetchTeam()).called(1);

      answer.complete(const Success([diego]));
      await pumpEventQueue();
      expect(vm.available, const [diego]);
    });

    test('uma falha ao baixar a sessão não trava nem avisa: a tela segue com '
        'o que tem', () async {
      when(() => participants.syncSession('sess-1'))
          .thenThrow(StateError('quebrou'));
      final vm = await open();

      await vm.refresh();

      expect(vm.errorMessage, isNull);
      expect(vm.message, isNull);
      expect(vm.available, const [diego, patricia]);
    });
  });

  group('quem pode mudar', () {
    test('o admin, numa sessão em andamento ou planejada', () async {
      final running = await open();
      expect(running.lockedReason, isNull);
      expect(running.canChange, isTrue);

      final planned = await open(
        withSession: session(status: SessionStatus.planejado),
      );
      expect(planned.canChange, isTrue);
    });

    test('consultor comum vê a lista travada, com o motivo', () async {
      final vm = await open(user: consultora);

      expect(vm.canChange, isFalse);
      expect(
        vm.lockedReason,
        'Só administradores podem mudar os consultores da sessão.',
      );

      await vm.add('c-diego');
      await vm.remove('c-tatiane');
      verifyNever(() => consultants.add(any(), any()));
      verifyNever(() => consultants.remove(any(), any()));
    });

    test('sessão concluída ou cancelada trava, com o motivo', () async {
      final done = await open(
        withSession: session(status: SessionStatus.concluido),
      );
      expect(done.canChange, isFalse);
      expect(
        done.lockedReason,
        'Sessão concluída: os consultores não podem mais ser alterados.',
      );

      final cancelled = await open(
        withSession: session(status: SessionStatus.cancelado),
      );
      expect(
        cancelled.lockedReason,
        'Sessão cancelada: os consultores não podem mais ser alterados.',
      );

      await done.add('c-diego');
      verifyNever(() => consultants.add(any(), any()));
    });

    test('sessão que não está no aparelho', () async {
      final vm = await open(missing: true);

      expect(vm.isLoading, isFalse);
      expect(vm.session, isNull);
      expect(vm.canChange, isFalse);
      expect(
        vm.lockedReason,
        'Esta sessão não está mais disponível neste aparelho.',
      );
    });

    test('a sessão ser concluída por outra pessoa trava a tela aberta',
        () async {
      final vm = await open();
      expect(vm.canChange, isTrue);

      sessionStream.add(session(status: SessionStatus.concluido));
      await pumpEventQueue();

      expect(vm.canChange, isFalse);
    });
  });

  group('adicionar', () {
    test('manda o consultor, avisa que entrou e baixa a sessão de novo',
        () async {
      final vm = await open();
      clearInteractions(participants);

      await vm.add('c-diego');

      verify(() => consultants.add('sess-1', 'c-diego')).called(1);
      expect(vm.message, 'Diego Barbosa entrou na sessão.');
      expect(vm.errorMessage, isNull);
      expect(vm.busyConsultantId, isNull);
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('durante o envio, só aquele consultor aparece ocupado, e outro toque '
        'não manda nada', () async {
      final answer = Completer<Result<void>>();
      when(() => consultants.add('sess-1', 'c-diego'))
          .thenAnswer((_) => answer.future);
      final vm = await open();

      final sending = vm.add('c-diego');
      await pumpEventQueue();

      expect(vm.busyConsultantId, 'c-diego');
      expect(vm.message, isNull);

      await vm.add('c-patricia');
      await vm.add('c-diego');
      await vm.remove('c-tatiane');
      verifyNever(() => consultants.add('sess-1', 'c-patricia'));
      verifyNever(() => consultants.remove(any(), any()));

      answer.complete(const Success<void>(null));
      await sending;

      verify(() => consultants.add('sess-1', 'c-diego')).called(1);
      expect(vm.busyConsultantId, isNull);
      expect(vm.message, 'Diego Barbosa entrou na sessão.');
    });

    test('quem não está na lista da equipe não é adicionado', () async {
      final vm = await open();

      await vm.add('c-nao-existe');
      // Já está na sessão: não aparece em "Disponíveis".
      await vm.add('c-rafael');

      verifyNever(() => consultants.add(any(), any()));
      expect(vm.message, isNull);
    });

    test('recusado pelo servidor: mostra o motivo, baixa a sessão e busca a '
        'equipe de novo', () async {
      when(() => consultants.add('sess-1', 'c-diego')).thenAnswer(
        (_) async => const Failure(
          ApiException(
            message: 'Consultor inativo não pode entrar em um treinamento',
            statusCode: 400,
          ),
          'Consultor inativo não pode entrar em um treinamento',
        ),
      );
      final vm = await open();
      clearInteractions(participants);
      clearInteractions(consultants);

      await vm.add('c-diego');
      await pumpEventQueue();

      expect(
        vm.errorMessage,
        'Consultor inativo não pode entrar em um treinamento',
      );
      expect(vm.message, isNull);
      expect(vm.busyConsultantId, isNull);
      verify(() => participants.syncSession('sess-1')).called(1);
      verify(() => consultants.fetchTeam()).called(1);
    });

    for (final status in const [403, 404, 409]) {
      test('recusa $status também baixa a sessão de novo', () async {
        when(() => consultants.add('sess-1', 'c-diego')).thenAnswer(
          (_) async => Failure(
            ApiException(message: 'recusado', statusCode: status),
            'recusado',
          ),
        );
        final vm = await open();
        clearInteractions(participants);

        await vm.add('c-diego');
        await pumpEventQueue();

        expect(vm.errorMessage, 'recusado');
        verify(() => participants.syncSession('sess-1')).called(1);
      });
    }

    test('sem rede: mostra o motivo e não baixa nada', () async {
      when(() => consultants.add('sess-1', 'c-diego')).thenAnswer(
        (_) async => const Failure(offlineError, 'Sem conexão com o servidor.'),
      );
      final vm = await open();
      clearInteractions(participants);
      clearInteractions(consultants);

      await vm.add('c-diego');
      await pumpEventQueue();

      expect(vm.errorMessage, 'Sem conexão com o servidor.');
      verifyNever(() => participants.syncSession(any()));
      verifyNever(() => consultants.fetchTeam());
    });

    test('erro do servidor (500): mostra o motivo e não baixa nada', () async {
      when(() => consultants.add('sess-1', 'c-diego')).thenAnswer(
        (_) async => const Failure(
          ApiException(message: 'Internal server error', statusCode: 500),
          'Não foi possível adicionar o consultor. Tente de novo.',
        ),
      );
      final vm = await open();
      clearInteractions(participants);

      await vm.add('c-diego');
      await pumpEventQueue();

      expect(
        vm.errorMessage,
        'Não foi possível adicionar o consultor. Tente de novo.',
      );
      verifyNever(() => participants.syncSession(any()));
    });

    test('uma exceção inesperada vira a mensagem genérica, sem travar a tela',
        () async {
      when(() => consultants.add('sess-1', 'c-diego'))
          .thenThrow(StateError('quebrou'));
      final vm = await open();

      await vm.add('c-diego');

      expect(
        vm.errorMessage,
        'Não foi possível adicionar o consultor. Tente de novo.',
      );
      expect(vm.busyConsultantId, isNull);
    });

    test('uma nova tentativa apaga o aviso da falha anterior', () async {
      when(() => consultants.add('sess-1', 'c-diego')).thenAnswer(
        (_) async => const Failure(offlineError, 'Sem conexão com o servidor.'),
      );
      final vm = await open();
      await vm.add('c-diego');
      expect(vm.errorMessage, isNotNull);

      final answer = Completer<Result<void>>();
      when(() => consultants.add('sess-1', 'c-diego'))
          .thenAnswer((_) => answer.future);
      final sending = vm.add('c-diego');
      await pumpEventQueue();

      expect(vm.errorMessage, isNull, reason: 'o aviso some já no toque');

      answer.complete(const Success<void>(null));
      await sending;
      expect(vm.errorMessage, isNull);
    });
  });

  group('remover', () {
    test('manda o consultor, avisa que saiu (sem o "(você)") e baixa a sessão '
        'de novo', () async {
      // O admin é consultor da sessão sem ser o responsável: pode se tirar.
      final vm = await open(withSession: session(responsible: 'c-rafael'));
      clearInteractions(participants);

      await vm.remove('c-carla');

      verify(() => consultants.remove('sess-1', 'c-carla')).called(1);
      expect(vm.message, 'Carla Mendes saiu da sessão.');
      expect(vm.errorMessage, isNull);
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('o responsável não é removido', () async {
      final vm = await open();

      await vm.remove('c-carla');

      verifyNever(() => consultants.remove(any(), any()));
    });

    test('quem não está na sessão não é removido', () async {
      final vm = await open();

      await vm.remove('c-diego');

      verifyNever(() => consultants.remove(any(), any()));
    });

    test('recusado pelo servidor: mostra o motivo e baixa a sessão de novo',
        () async {
      when(() => consultants.remove('sess-1', 'c-rafael')).thenAnswer(
        (_) async => const Failure(
          ApiException(
            message: 'Não é possível editar um treinamento concluído ou cancelado',
            statusCode: 403,
          ),
          'Não é possível editar um treinamento concluído ou cancelado',
        ),
      );
      final vm = await open();
      clearInteractions(participants);

      await vm.remove('c-rafael');
      await pumpEventQueue();

      expect(
        vm.errorMessage,
        'Não é possível editar um treinamento concluído ou cancelado',
      );
      expect(vm.message, isNull);
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('uma exceção inesperada vira a mensagem genérica', () async {
      when(() => consultants.remove('sess-1', 'c-rafael'))
          .thenThrow(StateError('quebrou'));
      final vm = await open();

      await vm.remove('c-rafael');

      expect(
        vm.errorMessage,
        'Não foi possível remover o consultor. Tente de novo.',
      );
    });

    test('dois toques rápidos removem uma vez só', () async {
      final answer = Completer<Result<void>>();
      when(() => consultants.remove('sess-1', 'c-rafael'))
          .thenAnswer((_) => answer.future);
      final vm = await open();

      final first = vm.remove('c-rafael');
      final second = vm.remove('c-rafael');
      await pumpEventQueue();
      expect(vm.busyConsultantId, 'c-rafael');

      answer.complete(const Success<void>(null));
      await Future.wait([first, second]);

      verify(() => consultants.remove('sess-1', 'c-rafael')).called(1);
    });
  });

  test('o aviso passageiro some quando a tela o consome', () async {
    final vm = await open();
    await vm.add('c-diego');
    expect(vm.message, isNotNull);

    vm.clearMessage();

    expect(vm.message, isNull);
  });

  test('fechar a tela com a resposta ainda viajando não derruba o app — e a '
      'sessão é baixada de novo mesmo assim', () async {
    final answer = Completer<Result<void>>();
    when(() => consultants.remove('sess-1', 'c-rafael'))
        .thenAnswer((_) => answer.future);
    final vm = SessionConsultantsViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      consultantRepository: consultants,
      connectivity: connectivity,
      currentUser: admin,
    )..init();
    sessionStream.add(session());
    consultantsStream.add(const [carla, rafael, tatiane]);
    participantsStream.add(const []);
    await pumpEventQueue();
    clearInteractions(participants);

    final sending = vm.remove('c-rafael');
    await pumpEventQueue();
    vm.dispose();

    answer.complete(const Success<void>(null));
    await sending;
    await pumpEventQueue();

    // Quem estava com o consultor foi liberado no servidor: o detalhe, que
    // ficou embaixo, lê do cache.
    verify(() => participants.syncSession('sess-1')).called(1);
  });

  group('baixar a sessão de novo', () {
    /// Um `syncSession` que só responde quando o teste manda: cada chamada vira
    /// um item da lista, na ordem em que saiu — o tamanho dela é quantos
    /// downloads já foram pedidos ao servidor.
    List<Completer<Result<int>>> holdDownloads() {
      final downloads = <Completer<Result<int>>>[];
      when(() => participants.syncSession('sess-1')).thenAnswer((_) {
        final download = Completer<Result<int>>();
        downloads.add(download);
        return download.future;
      });
      return downloads;
    }

    test('uma mudança aceita, com o download da abertura ainda no ar, espera '
        'por ele e baixa uma vez só depois', () async {
      final downloads = holdDownloads();
      final vm = await open();
      expect(downloads, hasLength(1), reason: 'o da abertura');

      await vm.add('c-diego');

      // O POST voltou, mas o GET da abertura pode ter sido respondido antes
      // dele: se chegasse por último, desfaria a mudança na tela.
      expect(vm.message, 'Diego Barbosa entrou na sessão.');
      expect(downloads, hasLength(1));

      downloads.first.complete(const Success(0));
      await pumpEventQueue();

      expect(downloads, hasLength(2));

      downloads.last.complete(const Success(0));
      await pumpEventQueue();

      expect(downloads, hasLength(2));
    });

    test('vários pedidos no meio — a volta da rede, o puxar para atualizar e '
        'uma mudança aceita — viram um só', () async {
      final downloads = holdDownloads();
      final vm = await open();

      connectivity.reconnect();
      final pulling = vm.refresh();
      await vm.add('c-diego');
      await pumpEventQueue();

      expect(downloads, hasLength(1));

      downloads.first.complete(const Success(0));
      await pumpEventQueue();
      await pulling;

      expect(downloads, hasLength(2));

      downloads.last.complete(const Success(0));
      await pumpEventQueue();

      expect(downloads, hasLength(2));
    });

    test('o enfileirado passa a ser o que está no ar: o pedido que chega '
        'durante ele espera pelo seguinte', () async {
      final downloads = holdDownloads();
      final vm = await open();
      await vm.add('c-diego');
      expect(downloads, hasLength(1));

      downloads.first.complete(const Success(0));
      await pumpEventQueue();
      expect(downloads, hasLength(2));

      await vm.remove('c-tatiane');
      expect(downloads, hasLength(2));

      downloads.last.complete(const Success(0));
      await pumpEventQueue();

      expect(downloads, hasLength(3));
    });

    test('um download que falha não trava a fila: o enfileirado roda, e o '
        'próximo pedido baixa na hora', () async {
      final downloads = holdDownloads();
      final vm = await open();
      await vm.add('c-diego');
      expect(downloads, hasLength(1));

      downloads.first.completeError(StateError('quebrou'));
      await pumpEventQueue();

      expect(downloads, hasLength(2));

      downloads.last.complete(const Success(0));
      await pumpEventQueue();
      await vm.remove('c-tatiane');

      expect(downloads, hasLength(3));
    });

    test('fechar a tela com um download enfileirado não o cancela: ele ainda '
        'roda', () async {
      final downloads = holdDownloads();
      final vm = SessionConsultantsViewModel(
        sessionId: 'sess-1',
        sessionRepository: sessions,
        participantRepository: participants,
        consultantRepository: consultants,
        connectivity: connectivity,
        currentUser: admin,
      )..init();
      sessionStream.add(session());
      consultantsStream.add(const [carla, rafael, tatiane]);
      participantsStream.add(const []);
      await pumpEventQueue();

      await vm.remove('c-rafael');
      vm.dispose();
      expect(downloads, hasLength(1));

      downloads.first.complete(const Success(0));
      await pumpEventQueue();

      // Quem estava com o consultor foi liberado no servidor, e o detalhe, que
      // ficou embaixo, lê do cache: o último a gravar tem de ser este.
      expect(downloads, hasLength(2));
    });
  });

  group('rótulos', () {
    test('consultantMetaLabel', () {
      expect(consultantMetaLabel(total: 0, inProgress: 0), 'Sem participantes');
      expect(
        consultantMetaLabel(total: 1, inProgress: 0),
        '1 participante concluído',
      );
      expect(
        consultantMetaLabel(total: 3, inProgress: 0),
        '3 participantes concluídos',
      );
      expect(
        consultantMetaLabel(total: 1, inProgress: 1),
        '1 participante · 1 em andamento',
      );
      expect(
        consultantMetaLabel(total: 4, inProgress: 2),
        '4 participantes · 2 em andamento',
      );
    });
  });
}
