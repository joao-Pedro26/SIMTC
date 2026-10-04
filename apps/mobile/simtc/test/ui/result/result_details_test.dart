import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/assessment_catalog.dart';
import 'package:simtc/data/models/remote_assessment.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/result/result_details.dart';

void main() {
  CatalogInfraction infraction(String id, String categoryId, int order) {
    return CatalogInfraction(
      id: id,
      categoryId: categoryId,
      description: 'Infração do item $order',
      order: order,
      notes: [
        CatalogNote(id: '$id-B', infractionId: id, noteType: 'B', deduction: 1),
        CatalogNote(
          id: '$id-PM',
          infractionId: id,
          noteType: 'PM',
          deduction: 3,
          comment: 'Comentário PM do item $order',
        ),
        CatalogNote(id: '$id-M', infractionId: id, noteType: 'M', deduction: 5),
      ],
    );
  }

  // CV com os itens 1 e 4; RR com o item 3.
  final catalog = [
    CatalogCategory(
      id: 'cat-cv',
      code: 'CV',
      name: 'Controle do Veículo',
      order: 1,
      infractions: [infraction('inf-1', 'cat-cv', 1), infraction('inf-4', 'cat-cv', 4)],
    ),
    CatalogCategory(
      id: 'cat-rr',
      code: 'RR',
      name: 'Respeito às Regras',
      order: 2,
      infractions: [infraction('inf-3', 'cat-rr', 3)],
    ),
  ];

  LocalAssessmentItem item(String infractionId, String noteId) {
    return LocalAssessmentItem(
      id: 'item-$infractionId',
      localAssessmentId: 'assess-1',
      infractionId: infractionId,
      infractionNoteId: noteId,
      updatedAt: DateTime(2026, 9, 30),
    );
  }

  RemoteAssessmentItem remoteItem({
    required String infractionId,
    required int order,
    required String noteType,
    required int deduction,
    String categoryId = 'cat-cv',
    String categoryCode = 'CV',
    String categoryName = 'Controle do Veículo',
    int categoryOrder = 1,
    String? comment,
  }) {
    return RemoteAssessmentItem(
      infractionNoteId: '$infractionId-$noteType',
      noteType: noteType,
      comment: comment,
      deduction: deduction,
      infractionId: infractionId,
      infractionDescription: 'Do servidor, item $order',
      infractionOrder: order,
      categoryId: categoryId,
      categoryCode: categoryCode,
      categoryName: categoryName,
      categoryOrder: categoryOrder,
    );
  }

  group('resultFromLocal', () {
    test(
        'cada categoria com o % do checklist e as infrações marcadas, com a nota '
        'e o comentário, na ordem do item', () {
      final categories = resultFromLocal(catalog, [
        item('inf-4', 'inf-4-B'),
        item('inf-1', 'inf-1-PM'),
      ]);

      expect(categories.map((c) => c.code), ['CV', 'RR']);
      final cv = categories.first;
      // Duas infrações em CV: PM (3/5 de 50) e B (1/5 de 50) descontam 40.
      expect(cv.score, 60);
      expect(cv.infractions.map((i) => i.number), [1, 4]);
      expect(cv.infractions.first.noteType, 'PM');
      expect(cv.infractions.first.description, 'Infração do item 1');
      expect(cv.infractions.first.comment, 'Comentário PM do item 1');
      expect(cv.infractions.last.comment, isNull);
      expect(categories.last.score, 100);
      expect(categories.last.infractions, isEmpty);
      expect(infractionCountOf(categories), 2);
    });
  });

  group('resultFromRemote', () {
    test('as infrações vêm da resposta, e o % de cada categoria do catálogo',
        () {
      final remote = RemoteAssessment(
        startTime: DateTime.utc(2026, 9, 30, 11),
        score: 85,
        items: [
          remoteItem(infractionId: 'inf-1', order: 1, noteType: 'PM', deduction: 3, comment: 'Do servidor'),
        ],
      );

      final categories = resultFromRemote(catalog, remote);

      expect(categories.map((c) => c.code), ['CV', 'RR']);
      expect(categories.first.score, 70, reason: 'PM numa categoria de 2 itens');
      expect(categories.first.infractions.single.description, 'Do servidor, item 1');
      expect(categories.first.infractions.single.comment, 'Do servidor');
      expect(categories.last.score, 100);
    });

    test('categoria que o catálogo do aparelho não conhece entra no fim, sem %',
        () {
      final remote = RemoteAssessment(
        startTime: DateTime.utc(2026, 9, 30, 11),
        items: [
          remoteItem(
            infractionId: 'inf-9',
            order: 2,
            noteType: 'M',
            deduction: 5,
            categoryId: 'cat-tp',
            categoryCode: 'TP',
            categoryName: 'Técnica de Pista',
            categoryOrder: 4,
          ),
        ],
      );

      final categories = resultFromRemote(catalog, remote);

      expect(categories.map((c) => c.code), ['CV', 'RR', 'TP']);
      expect(categories.last.score, isNull);
      expect(categories.last.infractions.single.number, 2);
    });

    test('sem catálogo no aparelho, só as categorias da resposta, sem %', () {
      final remote = RemoteAssessment(
        startTime: DateTime.utc(2026, 9, 30, 11),
        items: [
          remoteItem(infractionId: 'inf-4', order: 4, noteType: 'B', deduction: 1),
          remoteItem(infractionId: 'inf-1', order: 1, noteType: 'M', deduction: 5),
        ],
      );

      final categories = resultFromRemote(const [], remote);

      expect(categories.single.code, 'CV');
      expect(categories.single.score, isNull);
      expect(categories.single.infractions.map((i) => i.number), [1, 4]);
    });
  });
}
