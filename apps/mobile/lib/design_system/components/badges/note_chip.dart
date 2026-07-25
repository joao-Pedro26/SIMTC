import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/radius.dart';
import '../../tokens/typography.dart';
import '../assessment/note_selector.dart';

class NoteChip extends StatelessWidget {
  final NoteType note;
  const NoteChip(this.note, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = switch (note) {
      NoteType.B  => SimtcColors.noteB,
      NoteType.PM => SimtcColors.notePM,
      NoteType.M  => SimtcColors.noteM,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(SimtcRadius.full),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(note.label, style: SimtcTypography.label.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
