import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/ui/session_edit/session_edit_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

void main() {
  late _MockSessionRepository sessions;
  late _MockParticipantRepository participants;
  late StreamController<TrainingSession?> sessionStream;
  late StreamController<List<SessionParticipant>> participantsStream;

  const admin = AuthUser(
    id: 'u-admin',
    name: 'Sebastião Souza',
    email: 'admin@simtc.com.br',
    role: AppUserRole.admin,
    consultantId: 'c-admin',
  );
  const consultora = AuthUser(
    id: 'u1',
    name: 'Carla Souza',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-eu',
  );

  TrainingSession session({
    SessionStatus status = SessionStatus.emAndamento,
    String city = 'Itabira',
    String state = 'MG',
    String? notes = 'Pátio 3 — portaria B.',
    DateTime? date,
    bool withoutDate = false,
  }) {
    return TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell',
      courseName: 'Direção Defensiva',
      city: city,
      state: state,
      date: withoutDate ? null : (date ?? DateTime(2026, 9, 12)),
      status: status,
      notes: notes,
      totalParticipants: 0,
      assessableParticipants: 0,
      assessedParticipants: 0,
    );
  }

  SessionParticipant participant(String id, ParticipantStatus status) {
    return SessionParticipant(
      id: id,
      sessionId: 'sess-1',
      name: 'Participante $id',
      maskedCpf: '042.118.***-**',
      participationType: ParticipationType.teoricaEPratica,
      status: status,
    );
  }

  setUp(() {
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    sessionStream = StreamController<TrainingSession?>.broadcast();
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
    when(() => sessions.update(
          'sess-1',
          date: any(named: 'date'),
          city: any(named: 'city'),
          state: any(named: 'state'),
          notes: any(named: 'notes'),
        )).thenAnswer((_) async => const Success<void>(null));
    when(() => sessions.cancel('sess-1'))
        .thenAnswer((_) async => const Success<void>(null));
  });

  tearDown(() {
    sessionStream.close();
    participantsStream.close();
  });

  /// A tela aberta, com a sessão já lida do cache.
  Future<SessionEditViewModel> open({
    AuthUser? user = admin,
    TrainingSession? withSession,
    bool missing = false,
    DateTime Function()? now,
  }) async {
    final vm = SessionEditViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      currentUser: user,
      now: now,
    )..init();
    addTearDown(vm.dispose);
    sessionStream.add(missing ? null : (withSession ?? session()));
    participantsStream.add(const []);
    await pumpEventQueue();
    return vm;
  }

  group('abertura', () {
    test('antes da primeira leitura do cache, está carregando', () {
      final vm = SessionEditViewModel(
        sessionId: 'sess-1',
        sessionRepository: sessions,
        participantRepository: participants,
        currentUser: admin,
      )..init();
      addTearDown(vm.dispose);

      expect(vm.isLoading, isTrue);
      expect(vm.canEdit, isFalse);
    });

    test('traz os valores da sessão e não começa com mudança', () async {
      final vm = await open();

      expect(vm.isLoading, isFalse);
      expect(vm.date, DateTime(2026, 9, 12));
      expect(vm.city, 'Itabira');
      expect(vm.state, 'MG');
      expect(vm.notes, 'Pátio 3 — portaria B.');
      expect(vm.isDirty, isFalse);
      expect(vm.canSave, isFalse);
      expect(vm.canEdit, isTrue);
      expect(vm.lockedReason, isNull);
    });

    test('sessão sem data e sem observações abre com os campos vazios',
        () async {
      final vm = await open(withSession: session(withoutDate: true, notes: null));

      expect(vm.date, isNull);
      expect(vm.notes, '');
      expect(vm.isDirty, isFalse);
    });
  });

  group('quem pode editar', () {
    test('consultor comum vê os campos travados, com o motivo', () async {
      final vm = await open(user: consultora);

      expect(vm.canEdit, isFalse);
      expect(
        vm.lockedReason,
        'Só administradores podem alterar os dados do treinamento.',
      );
    });

    test('sessão concluída ou cancelada trava, com o motivo', () async {
      final concluded =
          await open(withSession: session(status: SessionStatus.concluido));
      expect(concluded.canEdit, isFalse);
      expect(
        concluded.lockedReason,
        'Sessão concluída: os dados não podem mais ser alterados.',
      );

      final cancelled =
          await open(withSession: session(status: SessionStatus.cancelado));
      expect(cancelled.canEdit, isFalse);
      expect(
        cancelled.lockedReason,
        'Sessão cancelada: os dados não podem mais ser alterados.',
      );
    });

    test('sessão planejada também pode ser editada', () async {
      final vm = await open(withSession: session(status: SessionStatus.planejado));

      expect(vm.canEdit, isTrue);
    });

    test('sessão que não está no aparelho', () async {
      final vm = await open(missing: true);

      expect(vm.isLoading, isFalse);
      expect(vm.session, isNull);
      expect(vm.canEdit, isFalse);
      expect(
        vm.lockedReason,
        'Esta sessão não está mais disponível neste aparelho.',
      );
    });

    test('a sessão ser concluída por outra pessoa trava a tela aberta', () async {
      final vm = await open();
      vm.setCity('Betim');
      expect(vm.canSave, isTrue);

      sessionStream.add(session(status: SessionStatus.concluido));
      await pumpEventQueue();

      expect(vm.canEdit, isFalse);
      expect(vm.canSave, isFalse);
      expect(vm.city, 'Betim', reason: 'o que foi digitado continua na tela');
    });
  });

  group('mudanças', () {
    test('mudar um campo marca a mudança; voltar ao valor original desmarca',
        () async {
      final vm = await open();

      vm.setCity('Betim');
      expect(vm.isDirty, isTrue);
      expect(vm.canSave, isTrue);

      vm.setCity('Itabira');
      expect(vm.isDirty, isFalse);
      expect(vm.canSave, isFalse);
    });

    test('espaço sobrando não conta como mudança', () async {
      final vm = await open();

      vm.setCity('  Itabira ');
      vm.setNotes('Pátio 3 — portaria B.  ');

      expect(vm.isDirty, isFalse);
    });

    test('escolher o mesmo dia não conta como mudança', () async {
      final vm = await open();

      vm.setDate(DateTime(2026, 9, 12, 15, 30));

      expect(vm.isDirty, isFalse);
    });

    test('um valor antigo fora do padrão não vira mudança só por abrir a tela',
        () async {
      // Cadastrado pelo painel web, que aceita texto livre na UF.
      final vm = await open(withSession: session(state: 'mg', city: 'Itabira '));

      expect(vm.isDirty, isFalse);
      expect(vm.stateError, isNull);
    });

    test('UF e cidade antigas fora do padrão não travam o salvar de outro campo',
        () async {
      // Só o campo que mudou é conferido: o valor antigo fica como está.
      final vm = await open(
        withSession: session(state: 'Minas Gerais', city: ''),
      );

      expect(vm.stateError, isNull);
      expect(vm.cityError, isNull);

      vm.setNotes('Levar colete.');

      expect(vm.canSave, isTrue);
      expect(await vm.save(), isTrue);
      verify(() => sessions.update(
            'sess-1',
            date: null,
            city: null,
            state: null,
            notes: 'Levar colete.',
          )).called(1);
    });

    test('um valor novo do cache não desfaz o que o admin digitou', () async {
      final vm = await open();
      vm.setCity('Betim');

      sessionStream.add(session(city: 'Contagem', notes: 'Outra observação.'));
      await pumpEventQueue();

      expect(vm.city, 'Betim');
      expect(vm.notes, 'Pátio 3 — portaria B.');
    });
  });

  // A lista de sessões só baixa as dos últimos 90 dias: uma data mais antiga
  // tira a sessão do app em todos os aparelhos (decisão de 09/10/2026).
  group('data antiga', () {
    // "Hoje" é 20/01/2027: a janela da lista começa em 22/10/2026.
    DateTime today() => DateTime(2027, 1, 20, 14, 30);

    test('a janela é a mesma da lista de sessões', () {
      expect(SessionRepository.historyWindowDays, 90);
    });

    test('data mudada para antes da janela pede confirmação', () async {
      final vm = await open(
        withSession: session(date: DateTime(2027, 1, 10)),
        now: today,
      );
      expect(vm.dateLeavesTheList, isFalse, reason: 'nada mudou ainda');

      vm.setDate(DateTime(2026, 10, 21));

      expect(vm.dateLeavesTheList, isTrue);
      expect(vm.canSave, isTrue, reason: 'a pergunta é da tela; salvar pode');
    });

    test('o primeiro dia da janela ainda está na lista; a véspera, não',
        () async {
      final vm = await open(
        withSession: session(date: DateTime(2027, 1, 10)),
        now: today,
      );

      vm.setDate(DateTime(2026, 10, 22));
      expect(vm.dateLeavesTheList, isFalse);

      vm.setDate(DateTime(2026, 10, 21));
      expect(vm.dateLeavesTheList, isTrue);
    });

    test('data recente ou futura não pergunta nada', () async {
      final vm = await open(
        withSession: session(date: DateTime(2027, 1, 10)),
        now: today,
      );

      vm.setDate(DateTime(2027, 1, 5));
      expect(vm.dateLeavesTheList, isFalse);

      vm.setDate(DateTime(2027, 6, 1));
      expect(vm.dateLeavesTheList, isFalse);
    });

    test('sessão que já tinha data antiga não pergunta ao mudar só outro campo',
        () async {
      final vm = await open(
        withSession: session(date: DateTime(2026, 5, 3)),
        now: today,
      );

      vm.setCity('Betim');

      expect(vm.isDirty, isTrue);
      expect(vm.dateLeavesTheList, isFalse);
    });

    test('escolher de novo o mesmo dia antigo não é mudança', () async {
      final vm = await open(
        withSession: session(date: DateTime(2026, 5, 3)),
        now: today,
      );

      vm.setDate(DateTime(2026, 5, 3, 9));

      expect(vm.dateLeavesTheList, isFalse);
    });

    test('trocar uma data antiga por outra data antiga pergunta', () async {
      final vm = await open(
        withSession: session(date: DateTime(2026, 5, 3)),
        now: today,
      );

      vm.setDate(DateTime(2026, 5, 4));

      expect(vm.dateLeavesTheList, isTrue);
    });

    test('sessão sem data, sem data escolhida: nada a perguntar', () async {
      final vm = await open(withSession: session(withoutDate: true), now: today);

      vm.setCity('Betim');

      expect(vm.dateLeavesTheList, isFalse);
    });

    test('sessão sem data que ganha uma data antiga pergunta', () async {
      final vm = await open(withSession: session(withoutDate: true), now: today);

      vm.setDate(DateTime(2026, 3, 1));

      expect(vm.dateLeavesTheList, isTrue);
    });
  });

  group('conferência', () {
    test('cidade apagada impede o salvar, com o motivo', () async {
      final vm = await open();

      vm.setCity('   ');

      expect(vm.cityError, 'Informe a cidade.');
      expect(vm.canSave, isFalse);
    });

    test('UF que não existe impede o salvar, com o motivo', () async {
      final vm = await open();

      vm.setState('XX');
      expect(vm.stateError, 'UF inválida.');
      expect(vm.canSave, isFalse);

      vm.setState('M');
      expect(vm.stateError, 'UF inválida.');

      vm.setState('sp');
      expect(vm.stateError, isNull, reason: 'minúsculas valem');
      expect(vm.canSave, isTrue);
    });
  });

  group('salvar', () {
    test('manda só o que mudou e devolve verdadeiro', () async {
      final vm = await open();
      vm.setDate(DateTime(2026, 10, 3));
      vm.setNotes('Levar colete.');

      final saved = await vm.save();

      expect(saved, isTrue);
      verify(() => sessions.update(
            'sess-1',
            date: DateTime(2026, 10, 3),
            city: null,
            state: null,
            notes: 'Levar colete.',
          )).called(1);
      expect(vm.isSaving, isFalse);
      expect(vm.errorMessage, isNull);
    });

    test('cidade e UF vão aparadas, e a UF em maiúsculas', () async {
      final vm = await open();
      vm.setCity('  Betim ');
      vm.setState('sp');

      await vm.save();

      verify(() => sessions.update(
            'sess-1',
            date: null,
            city: 'Betim',
            state: 'SP',
            notes: null,
          )).called(1);
    });

    test('observação apagada vai como texto vazio, para limpar no servidor',
        () async {
      final vm = await open();
      vm.setNotes('');

      await vm.save();

      verify(() => sessions.update(
            'sess-1',
            date: null,
            city: null,
            state: null,
            notes: '',
          )).called(1);
    });

    test('a data escolhida vai só com o dia, sem hora', () async {
      final vm = await open();
      vm.setDate(DateTime(2026, 10, 3, 15, 30));

      await vm.save();

      verify(() => sessions.update(
            'sess-1',
            date: DateTime(2026, 10, 3),
            city: null,
            state: null,
            notes: null,
          )).called(1);
    });

    test('sem mudança, não chama o repositório', () async {
      final vm = await open();

      expect(await vm.save(), isFalse);

      verifyNever(() => sessions.update(
            any(),
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          ));
    });

    test('falha: mostra o motivo, e o que foi digitado continua', () async {
      when(() => sessions.update(
            'sess-1',
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          )).thenAnswer(
        (_) async => const Failure<void>(
          ApiException(message: 'Sem conexão', isNetworkError: true),
          'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        ),
      );
      final vm = await open();
      vm.setCity('Betim');

      final saved = await vm.save();

      expect(saved, isFalse);
      expect(
        vm.errorMessage,
        'Sem conexão com o servidor. Verifique a internet e tente de novo.',
      );
      expect(vm.city, 'Betim');
      expect(vm.isDirty, isTrue);
      verifyNever(() => participants.syncSession(any()));
    });

    test('recusado pelo servidor (403): mostra o motivo e baixa a sessão de novo',
        () async {
      when(() => sessions.update(
            'sess-1',
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          )).thenAnswer(
        (_) async => const Failure<void>(
          ApiException(
            message: 'Não é possível editar um treinamento concluído ou cancelado',
            statusCode: 403,
          ),
          'Não é possível editar um treinamento concluído ou cancelado',
        ),
      );
      final vm = await open();
      vm.setCity('Betim');

      expect(await vm.save(), isFalse);

      expect(
        vm.errorMessage,
        'Não é possível editar um treinamento concluído ou cancelado',
      );
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('uma exceção inesperada vira a mensagem genérica, sem travar a tela',
        () async {
      when(() => sessions.update(
            'sess-1',
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          )).thenThrow(StateError('banco fechado'));
      final vm = await open();
      vm.setCity('Betim');

      expect(await vm.save(), isFalse);

      expect(
        vm.errorMessage,
        'Não foi possível salvar as alterações. Tente de novo.',
      );
      expect(vm.isSaving, isFalse);
    });

    test('mexer num campo apaga a mensagem de erro', () async {
      when(() => sessions.update(
            'sess-1',
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => Failure<void>(Exception('x'), 'Falhou.'));
      final vm = await open();
      vm.setCity('Betim');
      await vm.save();
      expect(vm.errorMessage, 'Falhou.');

      vm.setCity('Betim 2');

      expect(vm.errorMessage, isNull);
    });

    test('dois toques rápidos salvam uma vez só', () async {
      final answer = Completer<Result<void>>();
      when(() => sessions.update(
            'sess-1',
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) => answer.future);
      final vm = await open();
      vm.setCity('Betim');

      final first = vm.save();
      final second = vm.save();
      expect(vm.isSaving, isTrue);
      expect(vm.canSave, isFalse);
      answer.complete(const Success<void>(null));

      expect(await first, isTrue);
      expect(await second, isFalse);
      verify(() => sessions.update(
            'sess-1',
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          )).called(1);
    });
  });

  group('cancelar sessão', () {
    test('conta quem está em avaliação agora, para o aviso', () async {
      final vm = await open();
      expect(vm.inEvaluationCount, 0);

      participantsStream.add([
        participant('tp-1', ParticipantStatus.emAvaliacao),
        participant('tp-2', ParticipantStatus.pendente),
        participant('tp-3', ParticipantStatus.emAvaliacao),
        participant('tp-4', ParticipantStatus.aprovado),
      ]);
      await pumpEventQueue();

      expect(vm.inEvaluationCount, 2);
    });

    test('cancela e devolve verdadeiro', () async {
      final vm = await open();

      expect(await vm.cancelSession(), isTrue);

      verify(() => sessions.cancel('sess-1')).called(1);
      expect(vm.isCancelling, isFalse);
    });

    test('recusado pelo servidor: mostra o motivo e baixa a sessão de novo',
        () async {
      when(() => sessions.cancel('sess-1')).thenAnswer(
        (_) async => const Failure<void>(
          ApiException(
            message: 'Não é possível cancelar um treinamento já concluído',
            statusCode: 403,
          ),
          'Não é possível cancelar um treinamento já concluído',
        ),
      );
      final vm = await open();

      expect(await vm.cancelSession(), isFalse);

      expect(
        vm.errorMessage,
        'Não é possível cancelar um treinamento já concluído',
      );
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('quem não pode editar não cancela', () async {
      final vm = await open(user: consultora);

      expect(await vm.cancelSession(), isFalse);

      verifyNever(() => sessions.cancel(any()));
    });

    test('salvar e cancelar não correm juntos', () async {
      final answer = Completer<Result<void>>();
      when(() => sessions.cancel('sess-1')).thenAnswer((_) => answer.future);
      final vm = await open();
      vm.setCity('Betim');

      final cancelling = vm.cancelSession();
      expect(vm.isCancelling, isTrue);
      expect(vm.canSave, isFalse);
      expect(await vm.save(), isFalse);
      answer.complete(const Success<void>(null));
      await cancelling;

      verifyNever(() => sessions.update(
            any(),
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          ));
    });
  });

  test('fechar a tela com uma resposta ainda viajando não derruba o app',
      () async {
    final answer = Completer<Result<void>>();
    when(() => sessions.update(
          'sess-1',
          date: any(named: 'date'),
          city: any(named: 'city'),
          state: any(named: 'state'),
          notes: any(named: 'notes'),
        )).thenAnswer((_) => answer.future);
    final vm = SessionEditViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      currentUser: admin,
    )..init();
    sessionStream.add(session());
    await pumpEventQueue();
    vm.setCity('Betim');

    final saving = vm.save();
    vm.dispose();
    answer.complete(const Success<void>(null));

    expect(await saving, isTrue);
  });
}
