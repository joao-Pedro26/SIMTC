import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/cpf_lookup.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/ui/add_participant/add_participant_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

void main() {
  late _MockSessionRepository sessions;
  late _MockParticipantRepository participants;
  late StreamController<TrainingSession?> sessionStream;

  // Dois CPFs com os dígitos verificadores certos.
  const cpf = '52998224725';
  const otherCpf = '11144477735';

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

  const free = CpfLookup(registered: false, enrolled: false);
  const registered = CpfLookup(
    registered: true,
    enrolled: false,
    name: 'Fernanda Lopes Meireles',
    email: 'fernanda@empresa.com.br',
  );

  TrainingSession session({SessionStatus status = SessionStatus.emAndamento}) {
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
    );
  }

  SessionParticipant added({String name = 'Fernanda Lopes Meireles'}) {
    return SessionParticipant(
      id: 'tp-9',
      sessionId: 'sess-1',
      name: name,
      maskedCpf: '529.982.***-**',
      participationType: ParticipationType.teoricaEPratica,
      status: ParticipantStatus.pendente,
    );
  }

  void lookupAnswers(CpfLookup lookup, {String forCpf = cpf}) {
    when(() => participants.lookupCpf('sess-1', forCpf))
        .thenAnswer((_) async => Success(lookup));
  }

  void addAnswers(Result<SessionParticipant> result) {
    when(() => participants.add(
          'sess-1',
          cpf: any(named: 'cpf'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          participationType: any(named: 'participationType'),
        )).thenAnswer((_) async => result);
  }

  setUpAll(() => registerFallbackValue(ParticipationType.teoricaEPratica));

  setUp(() {
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    sessionStream = StreamController<TrainingSession?>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
    lookupAnswers(free);
    lookupAnswers(free, forCpf: otherCpf);
    addAnswers(Success(added()));
  });

  tearDown(() => sessionStream.close());

  /// A tela aberta, com a sessão já lida do cache.
  Future<AddParticipantViewModel> open({
    AuthUser? user = admin,
    TrainingSession? withSession,
    bool missing = false,
  }) async {
    final vm = AddParticipantViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      currentUser: user,
    )..init();
    addTearDown(vm.dispose);
    sessionStream.add(missing ? null : (withSession ?? session()));
    await pumpEventQueue();
    return vm;
  }

  /// CPF livre e nome preenchidos: pronto para adicionar.
  Future<AddParticipantViewModel> filled() async {
    final vm = await open();
    vm.setCpf(cpf);
    await pumpEventQueue();
    vm.setName('Fernanda Lopes Meireles');
    return vm;
  }

  group('abertura', () {
    test('começa vazia, com "Teórica + prática" marcado e sem poder adicionar',
        () async {
      final vm = await open();

      expect(vm.isLoading, isFalse);
      expect(vm.canAdd, isTrue);
      expect(vm.lockedReason, isNull);
      expect(vm.cpf, '');
      expect(vm.name, '');
      expect(vm.email, '');
      expect(vm.participationType, ParticipationType.teoricaEPratica);
      expect(vm.cpfCheck, CpfCheck.incomplete);
      expect(vm.canSubmit, isFalse);
      expect(vm.hasInput, isFalse);
      expect(vm.addedCount, 0);
    });

    test('sessão planejada também aceita participante', () async {
      final vm = await open(withSession: session(status: SessionStatus.planejado));

      expect(vm.canAdd, isTrue);
    });

    test('consultor comum, sessão concluída, cancelada ou fora do aparelho: '
        'travado, com o motivo', () async {
      final consultant = await open(user: consultora);
      expect(consultant.canAdd, isFalse);
      expect(
        consultant.lockedReason,
        'Só administradores podem adicionar participantes.',
      );

      final concluded =
          await open(withSession: session(status: SessionStatus.concluido));
      expect(
        concluded.lockedReason,
        'Sessão concluída: não dá mais para adicionar participantes.',
      );

      final cancelled =
          await open(withSession: session(status: SessionStatus.cancelado));
      expect(
        cancelled.lockedReason,
        'Sessão cancelada: não dá mais para adicionar participantes.',
      );

      final missing = await open(missing: true);
      expect(
        missing.lockedReason,
        'Esta sessão não está mais disponível neste aparelho.',
      );
    });
  });

  group('CPF', () {
    test('incompleto não consulta nem acusa erro', () async {
      final vm = await open();

      vm.setCpf('529.982.247');
      await pumpEventQueue();

      expect(vm.cpf, '529982247');
      expect(vm.cpfCheck, CpfCheck.incomplete);
      expect(vm.cpfError, isNull);
      expect(vm.cpfHelper, isNull);
      verifyNever(() => participants.lookupCpf(any(), any()));
    });

    test('dígitos verificadores errados: "CPF inválido.", sem consultar',
        () async {
      final vm = await open();

      vm.setCpf('529.982.247-26');
      await pumpEventQueue();

      expect(vm.cpfCheck, CpfCheck.invalid);
      expect(vm.cpfError, 'CPF inválido.');
      verifyNever(() => participants.lookupCpf(any(), any()));
    });

    test('válido: consulta com os dígitos e, livre, diz que pode seguir',
        () async {
      final vm = await open();

      vm.setCpf('529.982.247-25');
      expect(vm.cpfCheck, CpfCheck.checking);
      expect(vm.cpfHelper, 'Consultando o CPF…');
      await pumpEventQueue();

      verify(() => participants.lookupCpf('sess-1', cpf)).called(1);
      expect(vm.cpfCheck, CpfCheck.available);
      expect(vm.cpfHelper, 'CPF válido e sem cadastro nesta sessão.');
      expect(vm.cpfError, isNull);
      expect(vm.filledFromRegistry, isFalse);
      expect(vm.registryNotice, isNull);
    });

    test('o mesmo CPF de novo (só mudou a máscara) não consulta outra vez',
        () async {
      final vm = await open();
      vm.setCpf('529.982.247-25');
      await pumpEventQueue();

      vm.setCpf('52998224725');
      await pumpEventQueue();

      verify(() => participants.lookupCpf('sess-1', cpf)).called(1);
    });

    test('o que passa do 11º dígito é descartado', () async {
      final vm = await open();

      vm.setCpf('529982247259');

      expect(vm.cpf, cpf);
    });

    test('já inscrito nesta sessão: diz quem é e não deixa adicionar',
        () async {
      lookupAnswers(const CpfLookup(
        registered: true,
        enrolled: true,
        name: 'Fernanda Lopes Meireles',
      ));
      final vm = await open();

      vm.setCpf(cpf);
      await pumpEventQueue();
      vm.setName('Fernanda');

      expect(vm.cpfCheck, CpfCheck.enrolled);
      expect(vm.cpfError, 'Fernanda Lopes Meireles já está nesta sessão.');
      expect(vm.canSubmit, isFalse);
      expect(vm.name, 'Fernanda', reason: 'inscrito não preenche o formulário');
    });

    test(
        'já inscrito nesta sessão: baixa a sessão de novo, para a lista do '
        'detalhe mostrar a pessoa', () async {
      lookupAnswers(const CpfLookup(
        registered: true,
        enrolled: true,
        name: 'Fernanda Lopes Meireles',
      ));
      final vm = await open();

      // Um CPF livre não tem o que baixar.
      vm.setCpf(otherCpf);
      await pumpEventQueue();
      verifyNever(() => participants.syncSession(any()));

      vm.setCpf(cpf);
      await pumpEventQueue();

      expect(vm.cpfCheck, CpfCheck.enrolled);
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('consulta que falha: avisa e segue como formulário simples', () async {
      when(() => participants.lookupCpf('sess-1', cpf)).thenAnswer(
        (_) async => Failure<CpfLookup>(
          Exception('sem rede'),
          'Não foi possível consultar o CPF.',
        ),
      );
      final vm = await open();

      vm.setCpf(cpf);
      await pumpEventQueue();
      vm.setName('Fernanda Lopes Meireles');

      expect(vm.cpfCheck, CpfCheck.unverified);
      expect(
        vm.cpfHelper,
        'Não foi possível consultar o CPF. Preencha os dados e adicione assim mesmo.',
      );
      expect(vm.canSubmit, isTrue);
    });

    test('a resposta atrasada de um CPF que já foi trocado é ignorada',
        () async {
      final late = Completer<Result<CpfLookup>>();
      when(() => participants.lookupCpf('sess-1', cpf))
          .thenAnswer((_) => late.future);
      final vm = await open();

      vm.setCpf(cpf);
      vm.setCpf(otherCpf);
      await pumpEventQueue();
      expect(vm.cpfCheck, CpfCheck.available);

      late.complete(const Success(registered));
      await pumpEventQueue();

      expect(vm.cpf, otherCpf);
      expect(vm.cpfCheck, CpfCheck.available);
      expect(vm.name, '', reason: 'o cadastro era do CPF anterior');
      expect(vm.filledFromRegistry, isFalse);
    });

    test('enquanto consulta, não dá para adicionar', () async {
      final answer = Completer<Result<CpfLookup>>();
      when(() => participants.lookupCpf('sess-1', cpf))
          .thenAnswer((_) => answer.future);
      final vm = await open();
      vm.setName('Fernanda Lopes Meireles');

      vm.setCpf(cpf);

      expect(vm.cpfCheck, CpfCheck.checking);
      expect(vm.canSubmit, isFalse);

      answer.complete(const Success(free));
      await pumpEventQueue();
      expect(vm.canSubmit, isTrue);
    });
  });

  group('cadastro de outro treinamento', () {
    test('preenche nome e e-mail, e avisa que vieram do cadastro', () async {
      lookupAnswers(registered);
      final vm = await open();

      vm.setCpf(cpf);
      await pumpEventQueue();

      expect(vm.cpfCheck, CpfCheck.available);
      expect(vm.name, 'Fernanda Lopes Meireles');
      expect(vm.email, 'fernanda@empresa.com.br');
      expect(vm.filledFromRegistry, isTrue);
      expect(
        vm.registryNotice,
        'Já cadastrado em outro treinamento: nome e e-mail preenchidos. '
        'Altere se precisar.',
      );
      expect(vm.canSubmit, isTrue);
    });

    test('o que o admin já tinha digitado dá lugar ao cadastro', () async {
      lookupAnswers(registered);
      final vm = await open();
      vm.setName('Fernanda');

      vm.setCpf(cpf);
      await pumpEventQueue();

      expect(vm.name, 'Fernanda Lopes Meireles');
    });

    test('cadastro sem e-mail preenche só o nome, sem apagar o e-mail digitado',
        () async {
      lookupAnswers(const CpfLookup(
        registered: true,
        enrolled: false,
        name: 'Fernanda Lopes Meireles',
      ));
      final vm = await open();
      vm.setEmail('novo@empresa.com.br');

      vm.setCpf(cpf);
      await pumpEventQueue();

      expect(vm.name, 'Fernanda Lopes Meireles');
      expect(vm.email, 'novo@empresa.com.br');
      expect(vm.filledFromRegistry, isTrue);
      expect(
        vm.registryNotice,
        'Já cadastrado em outro treinamento: nome preenchido. Altere se precisar.',
      );
    });

    test('trocar o CPF limpa o que veio do cadastro — a pessoa é outra',
        () async {
      lookupAnswers(registered);
      final vm = await open();
      vm.setCpf(cpf);
      await pumpEventQueue();

      vm.setCpf(otherCpf);
      await pumpEventQueue();

      expect(vm.name, '');
      expect(vm.email, '');
      expect(vm.filledFromRegistry, isFalse);
      expect(vm.canSubmit, isFalse, reason: 'falta o nome');
    });

    test('apagar um dígito do CPF já limpa o que veio do cadastro', () async {
      lookupAnswers(registered);
      final vm = await open();
      vm.setCpf(cpf);
      await pumpEventQueue();

      vm.setCpf('5299822472');

      expect(vm.cpfCheck, CpfCheck.incomplete);
      expect(vm.name, '');
      expect(vm.email, '');
      expect(vm.filledFromRegistry, isFalse);
    });

    test('trocar o CPF não apaga o que o admin corrigiu à mão', () async {
      lookupAnswers(registered);
      final vm = await open();
      vm.setCpf(cpf);
      await pumpEventQueue();
      vm.setName('Fernanda L. Meireles');

      vm.setCpf(otherCpf);
      await pumpEventQueue();

      expect(vm.name, 'Fernanda L. Meireles');
      expect(vm.email, '', reason: 'o e-mail ele não tinha mexido');
    });

    test('trocar o CPF não apaga o e-mail que o admin corrigiu à mão', () async {
      lookupAnswers(registered);
      final vm = await open();
      vm.setCpf(cpf);
      await pumpEventQueue();
      vm.setEmail('fernanda.meireles@outraempresa.com.br');

      vm.setCpf(otherCpf);
      await pumpEventQueue();

      expect(vm.email, 'fernanda.meireles@outraempresa.com.br');
      expect(vm.name, '', reason: 'o nome ele não tinha mexido');
    });
  });

  group('demais campos', () {
    test('sem nome não adiciona', () async {
      final vm = await open();
      vm.setCpf(cpf);
      await pumpEventQueue();

      expect(vm.canSubmit, isFalse);
      vm.setName('   ');
      expect(vm.canSubmit, isFalse);
      vm.setName('Fernanda Lopes Meireles');
      expect(vm.canSubmit, isTrue);
    });

    test('e-mail é opcional; preenchido, precisa ter cara de e-mail', () async {
      final vm = await filled();
      expect(vm.isEmailValid, isTrue, reason: 'vazio vale');

      for (final wrong in ['fernanda', 'fernanda@', 'fernanda@empresa', 'a b@c.com']) {
        vm.setEmail(wrong);
        expect(vm.isEmailValid, isFalse, reason: wrong);
        expect(vm.canSubmit, isFalse, reason: wrong);
      }

      vm.setEmail(' fernanda@empresa.com.br ');
      expect(vm.isEmailValid, isTrue);
      expect(vm.canSubmit, isTrue);
    });

    test('qualquer campo preenchido conta como algo a perder ao fechar',
        () async {
      final vm = await open();

      vm.setName('F');
      expect(vm.hasInput, isTrue);
      vm.setName('');
      expect(vm.hasInput, isFalse);
      vm.setEmail('f');
      expect(vm.hasInput, isTrue);
      vm.setEmail('');
      vm.setCpf('5');
      expect(vm.hasInput, isTrue);
    });
  });

  group('adicionar', () {
    test('manda o CPF só com dígitos, o nome aparado e o tipo escolhido',
        () async {
      final vm = await open();
      vm.setCpf('529.982.247-25');
      await pumpEventQueue();
      vm.setName('  Fernanda Lopes Meireles ');
      vm.setEmail(' fernanda@empresa.com.br ');
      vm.setParticipationType(ParticipationType.somenteTeorica);

      final result = await vm.submit();

      expect(result?.id, 'tp-9');
      verify(() => participants.add(
            'sess-1',
            cpf: cpf,
            name: 'Fernanda Lopes Meireles',
            email: 'fernanda@empresa.com.br',
            participationType: ParticipationType.somenteTeorica,
          )).called(1);
      expect(vm.addedCount, 1);
      expect(vm.isSubmitting, isFalse);
      expect(vm.cpf, cpf,
          reason: 'sem "adicionar outro", o formulário fica como está: a tela fecha');
    });

    test('e-mail em branco vai nulo', () async {
      final vm = await filled();

      await vm.submit();

      verify(() => participants.add(
            'sess-1',
            cpf: cpf,
            name: 'Fernanda Lopes Meireles',
            email: null,
            participationType: ParticipationType.teoricaEPratica,
          )).called(1);
    });

    test('"Salvar e adicionar outro" limpa o formulário e conta quem entrou',
        () async {
      final vm = await filled();
      vm.setEmail('fernanda@empresa.com.br');
      vm.setParticipationType(ParticipationType.somenteTeorica);

      final result = await vm.submit(addAnother: true);

      expect(result?.name, 'Fernanda Lopes Meireles');
      expect(vm.cpf, '');
      expect(vm.name, '');
      expect(vm.email, '');
      expect(vm.participationType, ParticipationType.teoricaEPratica);
      expect(vm.cpfCheck, CpfCheck.incomplete);
      expect(vm.hasInput, isFalse);
      expect(vm.addedCount, 1);

      vm.setCpf(otherCpf);
      await pumpEventQueue();
      vm.setName('Diego Barbosa');
      await vm.submit(addAnother: true);
      expect(vm.addedCount, 2);
    });

    test(
        '"Salvar e adicionar outro" depois de um preenchimento pelo cadastro: '
        'o aviso do cadastro some com o formulário', () async {
      lookupAnswers(registered);
      final vm = await open();
      vm.setCpf(cpf);
      await pumpEventQueue();
      expect(vm.registryNotice, isNotNull, reason: 'nome e e-mail vieram do cadastro');

      await vm.submit(addAnother: true);

      expect(vm.registryNotice, isNull);
      expect(vm.filledFromRegistry, isFalse);
      expect(vm.name, '');
      expect(vm.email, '');
    });

    test('sem os dados mínimos, não chama o repositório', () async {
      final vm = await open();

      expect(await vm.submit(), isNull);

      verifyNever(() => participants.add(
            any(),
            cpf: any(named: 'cpf'),
            name: any(named: 'name'),
            email: any(named: 'email'),
            participationType: any(named: 'participationType'),
          ));
    });

    test(
        'CPF inscrito por outra pessoa entre a consulta e o toque (409): o '
        'aviso vai para o CPF', () async {
      addAnswers(const Failure<SessionParticipant>(
        ApiException(message: 'CPF já inscrito neste treinamento', statusCode: 409),
        'CPF já inscrito neste treinamento',
      ));
      final vm = await filled();

      expect(await vm.submit(), isNull);

      expect(vm.cpfCheck, CpfCheck.enrolled);
      expect(vm.cpfError, 'Este CPF já está nesta sessão.');
      expect(vm.errorMessage, isNull);
      expect(vm.canSubmit, isFalse);
      expect(vm.addedCount, 0);
    });

    test(
        'a recusa 409 também baixa a sessão de novo, para a lista do detalhe '
        'mostrar a pessoa', () async {
      addAnswers(const Failure<SessionParticipant>(
        ApiException(message: 'CPF já inscrito neste treinamento', statusCode: 409),
        'CPF já inscrito neste treinamento',
      ));
      final vm = await filled();

      await vm.submit();

      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('inscrições encerradas (400): mostra o motivo e baixa a sessão de novo',
        () async {
      addAnswers(const Failure<SessionParticipant>(
        ApiException(
          message: 'Inscrições encerradas para este treinamento',
          statusCode: 400,
        ),
        'Inscrições encerradas para este treinamento',
      ));
      final vm = await filled();

      expect(await vm.submit(), isNull);

      expect(vm.errorMessage, 'Inscrições encerradas para este treinamento');
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('sem rede: mostra o motivo, e o que foi digitado continua', () async {
      addAnswers(const Failure<SessionParticipant>(
        ApiException(message: 'Sem conexão', isNetworkError: true),
        'Sem conexão com o servidor. Verifique a internet e tente de novo.',
      ));
      final vm = await filled();

      expect(await vm.submit(addAnother: true), isNull);

      expect(
        vm.errorMessage,
        'Sem conexão com o servidor. Verifique a internet e tente de novo.',
      );
      expect(vm.cpf, cpf);
      expect(vm.name, 'Fernanda Lopes Meireles');
      expect(vm.canSubmit, isTrue, reason: 'dá para tentar de novo');
      verifyNever(() => participants.syncSession(any()));
    });

    test('uma exceção inesperada vira a mensagem genérica, sem travar a tela',
        () async {
      when(() => participants.add(
            'sess-1',
            cpf: any(named: 'cpf'),
            name: any(named: 'name'),
            email: any(named: 'email'),
            participationType: any(named: 'participationType'),
          )).thenThrow(StateError('banco fechado'));
      final vm = await filled();

      expect(await vm.submit(), isNull);

      expect(
        vm.errorMessage,
        'Não foi possível adicionar o participante. Tente de novo.',
      );
      expect(vm.isSubmitting, isFalse);
    });

    test('mexer num campo apaga a mensagem de erro', () async {
      addAnswers(Failure<SessionParticipant>(Exception('x'), 'Falhou.'));
      final vm = await filled();
      await vm.submit();
      expect(vm.errorMessage, 'Falhou.');

      vm.setName('Fernanda L. Meireles');

      expect(vm.errorMessage, isNull);
    });

    test('dois toques rápidos adicionam uma vez só', () async {
      final answer = Completer<Result<SessionParticipant>>();
      when(() => participants.add(
            'sess-1',
            cpf: any(named: 'cpf'),
            name: any(named: 'name'),
            email: any(named: 'email'),
            participationType: any(named: 'participationType'),
          )).thenAnswer((_) => answer.future);
      final vm = await filled();

      final first = vm.submit();
      final second = vm.submit(addAnother: true);
      expect(vm.isSubmitting, isTrue);
      expect(vm.canSubmit, isFalse);
      answer.complete(Success(added()));

      expect((await first)?.id, 'tp-9');
      expect(await second, isNull);
      expect(vm.addedCount, 1);
    });

    test('quem não pode adicionar não adiciona', () async {
      final vm = await open(user: consultora);
      vm.setCpf(cpf);
      await pumpEventQueue();
      vm.setName('Fernanda Lopes Meireles');

      expect(vm.canSubmit, isFalse);
      expect(await vm.submit(), isNull);
    });
  });

  test('fechar a tela com a consulta ainda viajando não derruba o app',
      () async {
    final answer = Completer<Result<CpfLookup>>();
    when(() => participants.lookupCpf('sess-1', cpf))
        .thenAnswer((_) => answer.future);
    final vm = AddParticipantViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      currentUser: admin,
    )..init();
    sessionStream.add(session());
    await pumpEventQueue();

    vm.setCpf(cpf);
    vm.dispose();
    answer.complete(const Success(registered));
    await pumpEventQueue();

    expect(vm.name, '');
  });
}
