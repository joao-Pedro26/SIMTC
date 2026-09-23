import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/local/app_database.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late List<String> logs;
  late AssessmentCatalogRepository repository;

  const path = '/assessment-categories';

  /// Uma categoria como `GET /assessment-categories` devolve: infrações e
  /// notas aninhadas (`include: { infractions: { include: { notes: true } } }`).
  Map<String, dynamic> category(
    String id, {
    required int order,
    List<Map<String, dynamic>> infractions = const [],
  }) {
    return {
      'id': id,
      'code': id.toUpperCase(),
      'name': 'Categoria $id',
      'description': null,
      'order': order,
      'infractions': infractions,
    };
  }

  Map<String, dynamic> infraction(String id, {required int order}) {
    return {
      'id': id,
      'description': 'Infração $id',
      'order': order,
      'notes': [
        {'id': '$id-b', 'noteType': 'B', 'comment': 'Leve', 'deduction': 1},
        {'id': '$id-pm', 'noteType': 'PM', 'comment': 'Média', 'deduction': 3},
        {'id': '$id-m', 'noteType': 'M', 'comment': null, 'deduction': 5},
      ],
    };
  }

  Response<List<dynamic>> ok(List<dynamic> body) {
    return Response<List<dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: body,
    );
  }

  setUp(() {
    api = _MockApiClient();
    db = AppDatabase(NativeDatabase.memory());
    logs = [];
    repository = AssessmentCatalogRepository(
      apiClient: api,
      database: db,
      log: logs.add,
    );
  });

  tearDown(() => db.close());

  test('grava categorias, infrações e notas e devolve na ordem da ficha',
      () async {
    when(() => api.get<List<dynamic>>(path)).thenAnswer(
      (_) async => ok([
        category('tp', order: 2),
        category('cv', order: 1, infractions: [
          infraction('cv2', order: 2),
          infraction('cv1', order: 1),
        ]),
      ]),
    );

    final result = await repository.sync();
    final catalog = await repository.loadCatalog();

    expect(result.dataOrNull, 2);
    expect(catalog.map((c) => c.id), ['cv', 'tp']);
    expect(catalog.first.infractions.map((i) => i.id), ['cv1', 'cv2']);
    expect(
      catalog.first.infractions.first.notes.map((n) => n.deduction),
      containsAll([1, 3, 5]),
    );
    expect(catalog.last.infractions, isEmpty);
  });

  test('um novo sync troca o catálogo inteiro, sem sobrar nada do antigo',
      () async {
    when(() => api.get<List<dynamic>>(path)).thenAnswer(
      (_) async => ok([
        category('cv', order: 1, infractions: [infraction('cv1', order: 1)]),
        category('tp', order: 2, infractions: [infraction('tp1', order: 1)]),
      ]),
    );
    await repository.sync();

    when(() => api.get<List<dynamic>>(path)).thenAnswer(
      (_) async => ok([
        category('cv', order: 1, infractions: [infraction('cv9', order: 1)]),
      ]),
    );
    await repository.sync();

    final catalog = await repository.loadCatalog();
    expect(catalog.map((c) => c.id), ['cv']);
    expect(catalog.single.infractions.map((i) => i.id), ['cv9']);
    expect(await db.select(db.infractionNotes).get(), hasLength(3));
  });

  test('sem rede, o catálogo do aparelho continua inteiro', () async {
    when(() => api.get<List<dynamic>>(path)).thenAnswer(
      (_) async => ok([
        category('cv', order: 1, infractions: [infraction('cv1', order: 1)]),
      ]),
    );
    await repository.sync();

    when(() => api.get<List<dynamic>>(path)).thenThrow(
      const ApiException(message: 'sem rede', isNetworkError: true),
    );

    final result = await repository.sync();

    expect(result.isFailure, isTrue);
    expect(await repository.loadCatalog(), hasLength(1));
  });

  test('resposta vazia não apaga o catálogo do aparelho', () async {
    when(() => api.get<List<dynamic>>(path)).thenAnswer(
      (_) async => ok([
        category('cv', order: 1, infractions: [infraction('cv1', order: 1)]),
      ]),
    );
    await repository.sync();

    when(() => api.get<List<dynamic>>(path)).thenAnswer((_) async => ok([]));

    final result = await repository.sync();

    expect(result.isFailure, isTrue);
    expect(await repository.loadCatalog(), hasLength(1));
  });

  test('registra no log o que ficou no aparelho, com sync ou sem', () async {
    when(() => api.get<List<dynamic>>(path)).thenAnswer(
      (_) async => ok([
        category('cv', order: 1, infractions: [infraction('cv1', order: 1)]),
      ]),
    );
    await repository.sync();

    when(() => api.get<List<dynamic>>(path)).thenThrow(
      const ApiException(message: 'sem rede', isNetworkError: true),
    );
    await repository.sync();

    expect(logs, [
      'Catálogo sincronizado. No aparelho: 1 categorias, 1 infrações, 3 notas.',
      'Catálogo não atualizado (sem rede). No aparelho: 1 categorias, '
          '1 infrações, 3 notas.',
    ]);
  });
}
