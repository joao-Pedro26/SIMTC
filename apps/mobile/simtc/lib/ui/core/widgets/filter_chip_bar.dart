import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Um filtro da barra: rótulo e, opcionalmente, um contador.
class FilterChipData {
  const FilterChipData({required this.label, this.count});

  final String label;
  final int? count;
}

/// Barra horizontal de filtros em pastilha (Todos / Pendentes / Meus / ...).
///
/// `StatefulWidget` só por causa disto: quando `selectedIndex` muda — seja
/// por toque num chip ou, na tela de sessões, pelo destaque automático da
/// rolagem manual — a barra rola horizontalmente até esse chip ficar
/// visível. Sem isso, o chip destacado por scroll pode ficar fora da faixa
/// visível em telas estreitas (ex.: 360dp com três chips e contadores), e o
/// feedback visual vira invisível justamente pra quem mais precisa dele.
class FilterChipBar extends StatefulWidget {
  const FilterChipBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<FilterChipData> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  State<FilterChipBar> createState() => _FilterChipBarState();
}

class _FilterChipBarState extends State<FilterChipBar> {
  late List<GlobalKey> _chipKeys = _buildKeys(widget.items.length);

  List<GlobalKey> _buildKeys(int length) =>
      List.generate(length, (_) => GlobalKey());

  @override
  void didUpdateWidget(covariant FilterChipBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _chipKeys = _buildKeys(widget.items.length);
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _ensureSelectedVisible();
    }
  }

  /// Espera o próximo frame — o chip recém-selecionado só ganha a cor/borda
  /// de destaque neste build, e `Scrollable.ensureVisible` precisa do
  /// `RenderObject` já montado com essa geometria pra calcular quanto rolar.
  void _ensureSelectedVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _chipKeys[widget.selectedIndex].currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs + 2),
            _buildChip(
              _chipKeys[i],
              widget.items[i],
              i == widget.selectedIndex,
              () => widget.onSelect(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(
    Key key,
    FilterChipData item,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final ink = isSelected ? AppColors.surface : AppColors.text2;

    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.borderStrong,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: AppTypography.chipLabel.copyWith(color: ink, fontSize: 12.5),
            ),
            if (item.count != null) ...[
              const SizedBox(width: AppSpacing.xs + 1),
              Text(
                '${item.count}',
                style: AppTypography.counter.copyWith(
                  color: ink.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
