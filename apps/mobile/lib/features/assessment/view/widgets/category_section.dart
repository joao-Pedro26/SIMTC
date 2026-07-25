import 'package:flutter/material.dart';
import '../../../../design_system/ds.dart';

/// Seção expansível de uma categoria de avaliação (CV, RR, CS...)
class CategorySection extends StatefulWidget {
  final String categoryCode;
  final String categoryName;
  final double score;
  final List<Widget> infractionRows;

  const CategorySection({
    required this.categoryCode,
    required this.categoryName,
    required this.score,
    required this.infractionRows,
    super.key,
  });

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: SimtcSpacing.md, vertical: SimtcSpacing.xs),
    child: Column(
      children: [
        CategoryHeader(
          code: widget.categoryCode,
          name: widget.categoryName,
          score: widget.score,
          isExpanded: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          ...widget.infractionRows,
        ],
      ],
    ),
  );
}
