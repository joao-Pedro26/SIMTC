import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/note_colors.dart';

void main() {
  group('noteFillColor', () {
    test('cada nota tem a sua cor cheia', () {
      expect(noteFillColor('B'), AppColors.noteBFill);
      expect(noteFillColor('PM'), AppColors.notePmFill);
      expect(noteFillColor('M'), AppColors.noteMFill);
    });

    test('valor desconhecido cai na cor de M', () {
      expect(noteFillColor('X'), AppColors.noteMFill);
    });
  });

  group('noteButtonColors', () {
    test('PM sem seleção usa o fundo, a borda e a tinta claros', () {
      expect(
        noteButtonColors('PM', selected: false),
        (bg: AppColors.notePmBg, border: AppColors.notePmBorder, ink: AppColors.notePmInk),
      );
    });

    test('PM selecionado usa a cor cheia no fundo e na borda', () {
      expect(
        noteButtonColors('PM', selected: true),
        (
          bg: AppColors.notePmFill,
          border: AppColors.notePmFill,
          ink: AppColors.notePmSelectedInk,
        ),
      );
    });

    test('B sem seleção e selecionado', () {
      expect(
        noteButtonColors('B', selected: false),
        (bg: AppColors.noteBBg, border: AppColors.noteBBorder, ink: AppColors.noteBInk),
      );
      expect(
        noteButtonColors('B', selected: true),
        (
          bg: AppColors.noteBFill,
          border: AppColors.noteBFill,
          ink: AppColors.noteBSelectedInk,
        ),
      );
    });

    test('M sem seleção e selecionado', () {
      expect(
        noteButtonColors('M', selected: false),
        (bg: AppColors.noteMBg, border: AppColors.noteMBorder, ink: AppColors.noteMInk),
      );
      expect(
        noteButtonColors('M', selected: true),
        (
          bg: AppColors.noteMFill,
          border: AppColors.noteMFill,
          ink: AppColors.noteMSelectedInk,
        ),
      );
    });

    test('valor desconhecido usa as cores de M', () {
      expect(
        noteButtonColors('X', selected: false),
        noteButtonColors('M', selected: false),
      );
    });
  });
}
