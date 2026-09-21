import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/sessions/session_filter.dart';
import 'package:simtc/ui/sessions/sessions_list_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

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
  late _MockSessionRepository repository;
  late _FakeConnectivity connectivity;
  late StreamController<List<TrainingSession>> sessions;

  final agora = DateTime(2026, 9, 20, 9);

  TrainingSession session(String id, {DateTime? date, SessionStatus? status}) {
    return TrainingSession(
      id: id,
      companyName: 'Bracell Celulose',
      courseName: 'Direção Preventiva',
      city: 'Lençóis Paulista',
      state: 'SP',
      date: date,
      status: status ?? SessionStatus.planejado,
      totalParticipants: 4,
      assessableParticipants: 4,
      assessedParticipants: 1,
    );
  }

  SessionsListViewModel build() => SessionsListViewModel(
        repository: repository,
        connectivity: connectivity,
        now: () => agora,
      );

  setUp(() {
    repository = _MockSessionRepository();
    connectivity = _FakeConnectivity();
    sessions = StreamController<List<TrainingSession>>.broadcast();

    when(repository.watchSessions).thenAnswer((_) => sessions.stream);
    when(repository.watchLastSyncedAt)
        .thenAnswer((_) => Stream.value(DateTime(2026, 9, 20, 8)));
    when(repository.syncAll).thenAnswer((_) async => const Success(1));
  });

  tearDown(() {
    sessions.close();
    connectivity.dispose();
  });

  test('começa carregando e sai do carregamento na primeira emissão', () async {
    final viewModel = build()..init();
    expect(viewModel.isLoading, isTrue);

    sessions.add([session('hoje', date: DateTime(2026, 9, 20, 8))]);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.groups.single.sessions.single.id, 'hoje');
  });

  test('sincroniza sozinho ao abrir', () async {
    build().init();
    await Future<void>.delayed(Duration.zero);

    verify(repository.syncAll).called(1);
  });

  test('sincroniza de novo quando a conexão volta', () async {
    build().init();
    await Future<void>.delayed(Duration.zero);

    connectivity.reconnect();
    await Future<void>.delayed(Duration.zero);

    verify(repository.syncAll).called(2);
  });

  test('os contadores dos chips não dependem do filtro escolhido', () async {
    final viewModel = build()..init();
    sessions.add([
      session('hoje', date: DateTime(2026, 9, 20, 8)),
      session('amanha', date: DateTime(2026, 9, 21, 8)),
      session('ok', status: SessionStatus.concluido),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.counts[SessionFilter.hoje], 1);
    expect(viewModel.counts[SessionFilter.proximos7], 1);
    expect(viewModel.counts[SessionFilter.concluidas], 1);
  });

  test('trocar o filtro remonta os grupos sem nova chamada de rede', () async {
    final viewModel = build()..init();
    sessions.add([session('amanha', date: DateTime(2026, 9, 21, 8))]);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.groups, isEmpty);

    viewModel.setFilter(SessionFilter.proximos7);

    expect(viewModel.groups.single.sessions.single.id, 'amanha');
    verify(repository.syncAll).called(1);
  });

  test('falha no refresh vira mensagem, sem apagar a lista', () async {
    final viewModel = build()..init();
    sessions.add([session('hoje', date: DateTime(2026, 9, 20, 8))]);
    await Future<void>.delayed(Duration.zero);

    when(repository.syncAll)
        .thenAnswer((_) async => Failure(Exception('sem rede'), 'Sem conexão.'));

    await viewModel.refresh();

    expect(viewModel.errorMessage, 'Sem conexão.');
    expect(viewModel.groups.single.sessions, hasLength(1));
  });

  test(
      'cache vazio e nunca sincronizado mantém o carregamento até o primeiro '
      'sync terminar', () async {
    // Cenário do primeiro login: o cache Drift está genuinamente vazio, o
    // stream emite `[]` na hora, e sem esta distinção a tela afirmaria "sem
    // sessão" enquanto ainda está baixando em 4G ruim.
    final syncCompleter = Completer<Result<int>>();
    when(repository.syncAll).thenAnswer((_) => syncCompleter.future);
    when(repository.watchLastSyncedAt).thenAnswer((_) => Stream.value(null));

    final viewModel = build()..init();
    sessions.add(const []);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isLoading, isTrue,
        reason: 'o primeiro sync ainda está em andamento');

    syncCompleter.complete(const Success(0));
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isLoading, isFalse,
        reason: 'o sync terminou; agora é um cache genuinamente vazio');
  });

  test(
      'uma exceção que escapa do Result não trava _isRefreshing: o próximo '
      'refresh funciona', () async {
    // Um defeito real do repository (ou de um mock de teste) pode lançar em
    // vez de devolver `Failure`. Sem o `finally`, `_isRefreshing` ficaria
    // preso em `true` e todo refresh seguinte cairia no guard-clause de
    // início de `refresh()` sem fazer nada.
    when(repository.syncAll).thenThrow(StateError('bug inesperado'));

    final viewModel = build()..init();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isRefreshing, isFalse);

    when(repository.syncAll).thenAnswer((_) async => const Success(1));
    await viewModel.refresh();

    verify(repository.syncAll).called(2);
    expect(viewModel.isRefreshing, isFalse);
  });
}
