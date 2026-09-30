import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/assessment_catalog.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/checklist/checklist_sections.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';

void main() {
  CatalogNote note(String id, String noteType, int deduction, {String? comment}) {
    return CatalogNote(
      id: id,
      infractionId: 'inf-shared',
      noteType: noteType,
      deduction: deduction,
      comment: comment,
    );
  }

  CatalogInfraction infraction(
    String id, {
    required int order,
    List<CatalogNote> notes = const [],
    String description = 'Descrição',
  }) {
    return CatalogInfraction(
      id: id,
      categoryId: 'cat-1',
      description: description,
      order: order,
      notes: notes,
    );
  }

  LocalAssessmentItem item(String infractionId, String noteId) {
    return LocalAssessmentItem(
      id: 'item-$infractionId',
      localAssessmentId: 'assess-1',
      infractionId: infractionId,
      infractionNoteId: noteId,
      updatedAt: DateTime(2026, 9, 25),
    );
  }

  group('buildChecklistSections', () {
    test('categoria sem nenhuma infração marcada vale 100 e não é revisada', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [
              note('note-b-1', 'B', 1),
              note('note-pm-1', 'PM', 3),
              note('note-m-1', 'M', 5),
            ]),
          ],
        ),
      ];

      final sections = buildChecklistSections(catalog, const []);

      expect(sections, hasLength(1));
      expect(sections.single.score, 100);
      expect(sections.single.isReviewed, isFalse);
      expect(sections.single.infractions.single.isMarked, isFalse);
    });

    test(
        'categoria "CV" do canvas: 6 infrações, uma PM e uma B marcadas — '
        'bate com o "86,7%" da spec', () {
      final infractions = [
        for (var i = 1; i <= 6; i++)
          infraction('inf-$i', order: i, notes: [
            note('note-b-$i', 'B', 1),
            note('note-pm-$i', 'PM', 3),
            note('note-m-$i', 'M', 5),
          ]),
      ];
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: infractions,
        ),
      ];
      final items = [item('inf-1', 'note-pm-1'), item('inf-2', 'note-b-2')];

      final sections = buildChecklistSections(catalog, items);

      expect(sections.single.score, closeTo(86.6666, 0.001));
      expect(sections.single.isReviewed, isTrue);
    });

    test('a nota escolhida traz sua observação, e as demais infrações ficam sem', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [
              note('note-b-1', 'B', 1, comment: 'Leve, sem risco imediato.'),
              note('note-pm-1', 'PM', 3, comment: 'Atenção reforçada.'),
              note('note-m-1', 'M', 5, comment: 'Risco grave.'),
            ]),
          ],
        ),
      ];

      final sections = buildChecklistSections(catalog, [item('inf-1', 'note-m-1')]);

      expect(sections.single.infractions.single.selectedComment, 'Risco grave.');
    });

    test('os 3 botões vêm sempre na ordem B, PM, M, mesmo se o catálogo vier fora de ordem', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [
              note('note-m-1', 'M', 5),
              note('note-b-1', 'B', 1),
              note('note-pm-1', 'PM', 3),
            ]),
          ],
        ),
      ];

      final sections = buildChecklistSections(catalog, const []);

      expect(
        sections.single.infractions.single.notes.map((n) => n.noteType),
        ['B', 'PM', 'M'],
      );
    });

    test('marcação de infração que não existe mais no catálogo é ignorada, sem quebrar', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [
              note('note-b-1', 'B', 1),
              note('note-pm-1', 'PM', 3),
              note('note-m-1', 'M', 5),
            ]),
          ],
        ),
      ];
      final items = [item('inf-1', 'note-b-1'), item('inf-orfa', 'note-x')];

      final sections = buildChecklistSections(catalog, items);

      expect(sections.single.infractions, hasLength(1));
      expect(sections.single.infractions.single.selectedNoteId, 'note-b-1');
    });

    test(
        'marcação com nota que não existe mais no catálogo aparece como "sem '
        'infração" — não conta como revisada nem no score', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [
              note('note-b-1', 'B', 1),
              note('note-pm-novo', 'PM', 3),
              note('note-m-1', 'M', 5),
            ]),
          ],
        ),
      ];

      final sections =
          buildChecklistSections(catalog, [item('inf-1', 'note-pm-antigo')]);

      final infraction1 = sections.single.infractions.single;
      expect(infraction1.selectedNoteId, isNull);
      expect(infraction1.isMarked, isFalse);
      expect(sections.single.isReviewed, isFalse);
      expect(sections.single.score, 100);
    });

    test('itens do catálogo sem id são descartados', () {
      final catalog = [
        const CatalogCategory(id: '', code: '??', name: 'Sem id', order: 0, infractions: []),
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('', order: 1),
            infraction('inf-1', order: 2, notes: [
              note('', 'B', 1),
              note('note-pm-1', 'PM', 3),
            ]),
          ],
        ),
      ];

      final sections = buildChecklistSections(catalog, const []);

      expect(sections.map((s) => s.id), ['cat-1']);
      expect(sections.single.infractions.map((i) => i.id), ['inf-1']);
      expect(sections.single.infractions.single.notes.map((n) => n.id), ['note-pm-1']);
    });

    test('duas categorias, uma revisada e outra não', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [note('note-b-1', 'B', 1)]),
          ],
        ),
        CatalogCategory(
          id: 'cat-2',
          code: 'TP',
          name: 'Transporte',
          order: 2,
          infractions: [
            infraction('inf-2', order: 1, notes: [note('note-b-2', 'B', 1)]),
          ],
        ),
      ];
      final items = [item('inf-1', 'note-b-1')];

      final sections = buildChecklistSections(catalog, items);

      expect(sections[0].isReviewed, isTrue);
      expect(sections[1].isReviewed, isFalse);
    });

    test('markedCount conta só as infrações com nota marcada', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [note('note-b-1', 'B', 1)]),
            infraction('inf-2', order: 2, notes: [note('note-b-2', 'B', 1)]),
            infraction('inf-3', order: 3, notes: [note('note-b-3', 'B', 1)]),
          ],
        ),
      ];
      final items = [item('inf-1', 'note-b-1'), item('inf-3', 'note-b-3')];

      final sections = buildChecklistSections(catalog, items);

      expect(sections.single.markedCount, 2);
    });
  });

  test('infractionCountLabel conta as marcações da categoria na tela 1.6', () {
    expect(infractionCountLabel(0), 'sem infração');
    expect(infractionCountLabel(1), '1 infração');
    expect(infractionCountLabel(3), '3 infrações');
  });

  group('overallScoreOf', () {
    test('é a média simples dos scores das categorias, mesmo as não abertas', () {
      final sections = [
        const ChecklistCategory(
            id: 'cat-1', code: 'CV', name: 'A', infractions: [], score: 86.6666666666),
        const ChecklistCategory(id: 'cat-2', code: 'TP', name: 'B', infractions: [], score: 100),
        const ChecklistCategory(id: 'cat-3', code: 'EQ', name: 'C', infractions: [], score: 100),
        const ChecklistCategory(id: 'cat-4', code: 'DO', name: 'D', infractions: [], score: 100),
      ];

      expect(overallScoreOf(sections), closeTo(96.6666, 0.001));
    });

    test('sem categorias, vale 100', () {
      expect(overallScoreOf(const []), 100);
    });
  });

  group('scoreBadgeColorsFor', () {
    test('85% ou mais usa o tom de sucesso', () {
      final colors = scoreBadgeColorsFor(85);
      expect(colors.bg, AppColors.successBg);
      expect(colors.ink, AppColors.successInk);
    });

    test('de 70% a 84,9% usa o tom PM', () {
      final colors = scoreBadgeColorsFor(80);
      expect(colors.bg, AppColors.notePmBg);
      expect(colors.ink, AppColors.notePmInk);
    });

    test('abaixo de 70% usa o tom M', () {
      final colors = scoreBadgeColorsFor(69.9);
      expect(colors.bg, AppColors.noteMBg);
      expect(colors.ink, AppColors.noteMInk);
    });
  });
}
