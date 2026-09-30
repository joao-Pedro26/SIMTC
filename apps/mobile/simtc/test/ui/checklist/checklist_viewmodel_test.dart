import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/checklist/checklist_viewmodel.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// Relógio mutável para o cronômetro nos testes: em vez de `fake_async`, o
/// `Timer.periodic` roda de verdade (com um intervalo bem curto) e o teste
/// avança este valor entre os ticks.
class _MutableClock {
  _MutableClock(this.value);
  DateTime value;
  DateTime call() => value;
}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;

  setUp(() {
    api = _MockApiClient();
    // Um dos testes é `testWidgets` (relógio falso): sem fechar os streams na
    // hora, o `Timer` de duração zero que o drift agenda ao cancelar um
    // stream ficaria pendente e derrubaria o teste.
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    assessmentRepository = AssessmentRepository(database: db);
    participantRepository = ParticipantRepository(apiClient: api, database: db);
    catalogRepository = AssessmentCatalogRepository(apiClient: api, database: db);
  });

  tearDown(() => db.close());

  Future<void> seedParticipant({String id = 'tp-1', String name = 'Carlos Eduardo Nunes'}) async {
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva',
            city: 'Itabira',
            state: 'MG',
            status: 'EM_ANDAMENTO',
            cachedAt: DateTime(2026, 9, 25, 8),
          ),
        );
    await db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: id,
            sessionId: 'sess-1',
            name: name,
            cpf: '187.443.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'EM_AVALIACAO',
            cachedAt: DateTime(2026, 9, 25, 8),
          ),
        );
  }

  Future<void> seedCatalog() async {
    await db.into(db.assessmentCategories).insert(
          AssessmentCategoriesCompanion.insert(
            id: 'cat-1',
            code: 'CV',
            name: 'Controle do Veículo',
            order: 1,
          ),
        );
    await db.into(db.infractions).insert(
          InfractionsCompanion.insert(
            id: 'inf-1',
            categoryId: 'cat-1',
            description: 'Excesso de velocidade',
            order: 1,
          ),
        );
    for (final n in [('note-b', 'B', 1), ('note-pm', 'PM', 3), ('note-m', 'M', 5)]) {
      await db.into(db.infractionNotes).insert(
            InfractionNotesCompanion.insert(
              id: n.$1,
              infractionId: 'inf-1',
              noteType: n.$2,
              deduction: n.$3,
            ),
          );
    }
  }

  ChecklistViewModel buildViewModel({DateTime Function()? now, Duration? tickInterval}) {
    return ChecklistViewModel(
      sessionId: 'sess-1',
      participantId: 'tp-1',
      ownerUserId: 'user-1',
      assessmentRepository: assessmentRepository,
      participantRepository: participantRepository,
      catalogRepository: catalogRepository,
      now: now,
      tickInterval: tickInterval ?? const Duration(seconds: 1),
    );
  }

  group('init', () {
    test('carrega o participante, o catálogo e sai de loading', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);

      expect(vm.isLoading, isTrue);
      await vm.init();

      expect(vm.isLoading, isFalse);
      expect(vm.participant?.name, 'Carlos Eduardo Nunes');
      expect(vm.sections, hasLength(1));
      expect(vm.sections.single.infractions, hasLength(1));
      expect(vm.expandedCategoryId, 'cat-1', reason: 'abre com a primeira categoria aberta');
    });

    test('retomar o checklist reabre o mesmo rascunho, sem perder marcações', () async {
      await seedParticipant();
      await seedCatalog();

      final first = buildViewModel();
      await first.init();
      await first.toggleNote('inf-1', 'note-pm');
      first.dispose();

      final second = buildViewModel();
      addTearDown(second.dispose);
      await second.init();

      expect(second.sections.single.infractions.single.selectedNoteId, 'note-pm');
    });
  });

  group('toggleNote', () {
    test('marca a infração e o score da categoria cai', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();

      await vm.toggleNote('inf-1', 'note-m');

      expect(vm.sections.single.infractions.single.selectedNoteId, 'note-m');
      expect(vm.sections.single.score, 0);
      expect(vm.reviewedCount, 1);
      expect(vm.unreviewedCount, 0);
      expect(vm.hasUnreviewedCategories, isFalse);
    });

    test('apertar a mesma nota de novo desmarca a infração', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.toggleNote('inf-1', 'note-b');

      await vm.toggleNote('inf-1', 'note-b');

      expect(vm.sections.single.infractions.single.selectedNoteId, isNull);
      expect(vm.sections.single.score, 100);
      expect(vm.unreviewedCount, 1);
      expect(vm.hasUnreviewedCategories, isTrue);
    });
  });

  group('toggleCategory', () {
    test('abrir outra categoria fecha a aberta; tocar na aberta fecha', () async {
      await seedParticipant();
      await seedCatalog();
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(
              id: 'cat-2',
              code: 'RR',
              name: 'Respeito às Regras',
              order: 2,
            ),
          );
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      expect(vm.expandedCategoryId, 'cat-1');

      vm.toggleCategory('cat-2');
      expect(vm.expandedCategoryId, 'cat-2');

      vm.toggleCategory('cat-2');
      expect(vm.expandedCategoryId, isNull);
    });
  });

  group('elapsedLabel', () {
    test('avança conforme o relógio injetado, sem esperar tempo real', () async {
      await seedParticipant();
      await seedCatalog();
      // `openDraft` grava `startTime` com o relógio real — a base do relógio
      // falso precisa ser próxima do "agora" de verdade, senão a diferença
      // fica negativa e o formato trava em zero.
      final clock = _MutableClock(DateTime.now());
      final vm = buildViewModel(now: clock.call, tickInterval: const Duration(milliseconds: 5));
      addTearDown(vm.dispose);
      await vm.init();

      expect(vm.elapsedLabel, '00:00:00');

      clock.value = clock.value.add(const Duration(hours: 1, minutes: 2, seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(vm.elapsedLabel, '01:02:03');
    });

    test('o cronômetro avisa a tela a cada tick', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel(tickInterval: const Duration(milliseconds: 5));
      addTearDown(vm.dispose);
      await vm.init();

      var notifications = 0;
      vm.addListener(() => notifications++);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(notifications, greaterThan(0),
          reason: 'o elapsedLabel é calculado na leitura; sem o aviso do tick, '
              'o cronômetro da tela ficaria parado');
    });
  });

  group('finish', () {
    test('marca local, sinaliza isFinished e para o cronômetro', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel(tickInterval: const Duration(milliseconds: 5));
      addTearDown(vm.dispose);
      await vm.init();

      await vm.finish();

      expect(vm.isFinished, isTrue);
      final row = await db.select(db.localAssessments).getSingle();
      expect(row.syncStatus, LocalSyncStatus.pendingSync);
      expect(row.endTime, isNotNull);

      var notifications = 0;
      vm.addListener(() => notifications++);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(notifications, 0, reason: 'sem cronômetro, ninguém notifica mais');
    });

    test('sem catálogo no aparelho, não finaliza — uma avaliação vazia daria 100%',
        () async {
      await seedParticipant();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();

      expect(vm.hasCatalog, isFalse);
      await vm.finish();

      expect(vm.isFinished, isFalse);
      final row = await db.select(db.localAssessments).getSingle();
      expect(row.syncStatus, LocalSyncStatus.draft);
    });

    test(
        'catálogo só com categoria sem id vale como sem catálogo — nada a '
        'avaliar, então também não finaliza', () async {
      await seedParticipant();
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(
              id: '',
              code: '??',
              name: 'Categoria sem id',
              order: 1,
            ),
          );
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();

      expect(vm.hasCatalog, isFalse);
      await vm.finish();

      expect(vm.isFinished, isFalse);
    });
  });

  testWidgets('dispose cancela o cronômetro: nenhum timer fica pendente', (tester) async {
    await seedParticipant();
    await seedCatalog();
    final vm = buildViewModel();
    await vm.init();
    expect(vm.isLoading, isFalse, reason: 'o init terminou e ligou o cronômetro');

    vm.dispose();
    // O `testWidgets` falha sozinho se terminar com um `Timer` pendente: um
    // `Timer.periodic` que o dispose esquecesse de cancelar ficaria aqui.
  });

  test('uma escrita que termina depois do dispose não notifica a tela morta',
      () async {
    await seedParticipant();
    await seedCatalog();
    final vm = buildViewModel();
    await vm.init();

    final pending = vm.toggleNote('inf-1', 'note-b');
    vm.dispose();

    // Sem a guarda, o `notifyListeners` do fim do `toggleNote` lançaria
    // "used after being disposed" e esta escrita terminaria com erro.
    await expectLater(pending, completes);
  });
}
