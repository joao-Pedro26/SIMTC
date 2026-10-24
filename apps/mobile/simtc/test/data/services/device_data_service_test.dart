import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/services/device_data_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/data/services/local/token_storage.dart';

class _MockTokenStorage extends Mock implements TokenStorage {}

class _FakeLogoCache implements LogoCache {
  int bytes = 0;
  int clears = 0;
  bool failClear = false;

  @override
  Future<int> sizeInBytes() async => bytes;

  @override
  Future<void> clear() async {
    clears++;
    if (failClear) throw Exception('pasta presa');
  }
}

void main() {
  const production = 'https://api.simtc.com.br/api';
  const local = 'http://localhost:3001/api';

  late AppDatabase db;
  late _MockTokenStorage storage;
  late _FakeLogoCache logos;
  late DeviceDataService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    storage = _MockTokenStorage();
    logos = _FakeLogoCache();
    service = DeviceDataService(database: db, storage: storage, logos: logos);
    when(() => storage.clear()).thenAnswer((_) async {});
    when(() => storage.saveApiBaseUrl(any())).thenAnswer((_) async {});
  });

  tearDown(() => db.close());

  /// Uma sessão com [participants] participantes e um consultor, o catálogo
  /// com uma nota, e um rascunho com uma marcação.
  Future<void> seed({int participants = 1}) async {
    final at = DateTime(2026, 10, 24, 8);
    await db.into(db.sessions).insert(SessionsCompanion.insert(
          id: 'sess-1',
          companyName: 'Bracell Celulose',
          courseName: 'Direção Preventiva',
          city: 'Lençóis Paulista',
          state: 'SP',
          status: 'EM_ANDAMENTO',
          cachedAt: at,
        ));
    for (var i = 0; i < participants; i++) {
      await db.into(db.participants).insert(ParticipantsCompanion.insert(
            id: 'tp-$i',
            sessionId: 'sess-1',
            name: 'Participante com um nome bem comprido para ocupar espaço $i',
            cpf: '***.456.789-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'PENDENTE',
            cachedAt: at,
          ));
    }
    await db.into(db.sessionConsultants).insert(SessionConsultantsCompanion.insert(
          sessionId: 'sess-1',
          consultantId: 'c-1',
          name: 'Carla Mendes',
        ));
    await db.into(db.assessmentCategories).insert(
        AssessmentCategoriesCompanion.insert(id: 'cat-1', code: 'A', name: 'Antes', order: 1));
    await db.into(db.infractions).insert(InfractionsCompanion.insert(
        id: 'inf-1', categoryId: 'cat-1', description: 'Cinto', order: 1));
    await db.into(db.infractionNotes).insert(InfractionNotesCompanion.insert(
        id: 'note-1', infractionId: 'inf-1', noteType: 'M', deduction: 3));
    await db.into(db.localAssessments).insert(LocalAssessmentsCompanion.insert(
          id: 'local-1',
          trainingParticipantId: 'tp-0',
          sessionId: 'sess-1',
          date: DateTime(2026, 10, 24),
          startTime: at,
          syncStatus: LocalSyncStatus.pendingSync,
          createdAt: at,
          updatedAt: at,
        ));
    await db.into(db.localAssessmentItems).insert(LocalAssessmentItemsCompanion.insert(
          id: 'item-1',
          localAssessmentId: 'local-1',
          infractionId: 'inf-1',
          infractionNoteId: 'note-1',
          updatedAt: at,
        ));
  }

  Future<Map<String, int>> counts() async => {
        'sessões': (await db.select(db.sessions).get()).length,
        'participantes': (await db.select(db.participants).get()).length,
        'consultores': (await db.select(db.sessionConsultants).get()).length,
        'categorias': (await db.select(db.assessmentCategories).get()).length,
        'infrações': (await db.select(db.infractions).get()).length,
        'notas': (await db.select(db.infractionNotes).get()).length,
        'avaliações': (await db.select(db.localAssessments).get()).length,
        'marcações': (await db.select(db.localAssessmentItems).get()).length,
      };

  const everything = {
    'sessões': 1,
    'participantes': 1,
    'consultores': 1,
    'categorias': 1,
    'infrações': 1,
    'notas': 1,
    'avaliações': 1,
    'marcações': 1,
  };

  const nothing = {
    'sessões': 0,
    'participantes': 0,
    'consultores': 0,
    'categorias': 0,
    'infrações': 0,
    'notas': 0,
    'avaliações': 0,
    'marcações': 0,
  };

  group('troca de servidor', () {
    test('o mesmo servidor da última abertura não apaga nada', () async {
      await seed();
      when(() => storage.readApiBaseUrl()).thenAnswer((_) async => production);

      expect(await service.resetIfServerChanged(production), isFalse);

      expect(await counts(), everything);
      verifyNever(() => storage.clear());
      verifyNever(() => storage.saveApiBaseUrl(any()));
      expect(logos.clears, 0);
    });

    test('outro servidor apaga tudo — inclusive a fila e os rascunhos —, o '
        'login e os logos, e guarda o endereço novo', () async {
      await seed();
      when(() => storage.readApiBaseUrl()).thenAnswer((_) async => local);

      expect(await service.resetIfServerChanged(production), isTrue);

      expect(await counts(), nothing);
      verify(() => storage.clear()).called(1);
      expect(logos.clears, 1);
      verify(() => storage.saveApiBaseUrl(production)).called(1);
    });

    test('nenhum endereço guardado conta como troca', () async {
      await seed();
      when(() => storage.readApiBaseUrl()).thenAnswer((_) async => null);

      expect(await service.resetIfServerChanged(production), isTrue);

      expect(await counts(), nothing);
      verify(() => storage.saveApiBaseUrl(production)).called(1);
    });

    test('sem conseguir ler o endereço guardado, não apaga nada', () async {
      await seed();
      when(() => storage.readApiBaseUrl()).thenThrow(Exception('keystore'));

      expect(await service.resetIfServerChanged(production), isFalse);

      expect(await counts(), everything);
      verifyNever(() => storage.saveApiBaseUrl(any()));
    });

    test('falha ao apagar o login ou os logos não impede a troca', () async {
      await seed();
      when(() => storage.readApiBaseUrl()).thenAnswer((_) async => local);
      when(() => storage.clear()).thenThrow(Exception('keystore'));
      logos.failClear = true;

      expect(await service.resetIfServerChanged(production), isTrue);

      expect(await counts(), nothing);
      verify(() => storage.saveApiBaseUrl(production)).called(1);
    });
  });

  group('limpar cache local', () {
    test('apaga sessões, participantes, consultores, catálogo e logos, e '
        'mantém a fila e os rascunhos', () async {
      await seed();

      await service.clearDownloaded();

      expect(await counts(), {
        ...nothing,
        'avaliações': 1,
        'marcações': 1,
      });
      expect(logos.clears, 1);
      verifyNever(() => storage.clear());
    });

    test('o espaço é o do banco mais o dos logos, e cai depois de limpar',
        () async {
      await seed(participants: 400);
      logos.bytes = 5000;

      final before = await service.downloadedBytes();
      expect(before, await db.usedBytes() + 5000);

      await service.clearDownloaded();
      logos.bytes = 0;

      expect(await service.downloadedBytes(), lessThan(before - 5000));
    });

    test('uma falha ao apagar os logos não desfaz a limpeza do banco',
        () async {
      await seed();
      logos.failClear = true;

      await service.clearDownloaded();

      expect((await counts())['sessões'], 0);
    });
  });
}
