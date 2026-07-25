import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';
import '../../tokens/radius.dart';
import '../../tokens/typography.dart';

enum NoteType { B, PM, M }

extension NoteTypeExt on NoteType {
  String get label => switch (this) { NoteType.B => 'B', NoteType.PM => 'PM', NoteType.M => 'M' };
  int get deduction => switch (this) { NoteType.B => 0, NoteType.PM => 3, NoteType.M => 5 };
}

class NoteSelector extends StatelessWidget {
  final NoteType? selected;
  final void Function(NoteType) onSelect;
  final bool enabled;

  const NoteSelector({
    required this.onSelect,
    this.selected,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: NoteType.values.map((note) {
        final isSelected = selected == note;
        return Padding(
          padding: const EdgeInsets.only(left: SimtcSpacing.xs),
          child: GestureDetector(
            onTap: enabled ? () => onSelect(note) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: const EdgeInsets.symmetric(
                horizontal: SimtcSpacing.sm,
                vertical: SimtcSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isSelected ? _colorFor(note) : SimtcColors.surface,
                borderRadius: BorderRadius.circular(SimtcRadius.sm),
                border: Border.all(
                  color: isSelected ? _colorFor(note) : SimtcColors.border,
                ),
              ),
              child: Text(
                note.label,
                textAlign: TextAlign.center,
                style: SimtcTypography.label.copyWith(
                  color: isSelected ? Colors.white : _colorFor(note),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _colorFor(NoteType note) => switch (note) {
    NoteType.B  => SimtcColors.noteB,
    NoteType.PM => SimtcColors.notePM,
    NoteType.M  => SimtcColors.noteM,
  };
}
