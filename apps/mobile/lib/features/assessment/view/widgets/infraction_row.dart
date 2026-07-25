import 'package:flutter/material.dart';
import '../../../../design_system/ds.dart';

class InfractionRow extends StatelessWidget {
  final String description;
  final NoteType? selectedNote;
  final void Function(NoteType) onSelect;

  const InfractionRow({
    required this.description,
    required this.selectedNote,
    required this.onSelect,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: SimtcSpacing.md,
      vertical: SimtcSpacing.sm,
    ),
    child: Row(
      children: [
        Expanded(child: Text(description, style: SimtcTypography.body)),
        NoteSelector(selected: selectedNote, onSelect: onSelect),
      ],
    ),
  );
}
