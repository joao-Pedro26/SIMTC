import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Item da navbar flutuante.
class PillNavItem {
  const PillNavItem({
    required this.icon,
    required this.label,
    this.shortLabel,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;

  /// Rótulo da navbar lateral, onde o item tem 64 de largura ("Sincr.", no
  /// quadro "4c"). Sem ele, vale [label].
  final String? shortLabel;

  /// Quantidade pendente exibida em cima do ícone; 0 esconde o badge.
  final int badgeCount;
}

/// As três formas da mesma navbar.
enum PillNavLayout {
  /// Pílula na base do celular, com o recuo das bordas embutido.
  phone,

  /// Pílula na base do tablet em retrato (quadro "4u"). Quem posiciona é o
  /// `TabletNavFrame`: a barra não traz recuo próprio.
  tabletBottom,

  /// Coluna na lateral do tablet em paisagem (quadro "4c"). Também
  /// posicionada pelo `TabletNavFrame`.
  rail,
}

/// Navbar em pastilha flutuante (Sessões / Sincronizar / Perfil).
///
/// Fundo opaco, não translúcido: o app é usado dentro do veículo, com luz
/// variável, onde contraste previsível vale mais que o efeito de vidro.
class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.items,
    this.layout = PillNavLayout.phone,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<PillNavItem> items;
  final PillNavLayout layout;

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      PillNavLayout.phone => _buildPhone(),
      PillNavLayout.tabletBottom => _buildTabletBottom(),
      PillNavLayout.rail => _buildRail(),
    };
  }

  Widget _buildPhone() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Container(
        height: 64,
        padding: const EdgeInsets.all(AppSpacing.sm - 2),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: const [
            BoxShadow(
              color: AppColors.navShadow,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(child: _buildItem(items[i], i == currentIndex, () => onSelect(i))),
          ],
        ),
      ),
    );
  }

  /// Os quadros do tablet desenham a barra com borda. O item ativo em
  /// `primarySurface`/`primaryDark` vale também para o celular (Fase 8C).
  static final BoxDecoration _tabletDecoration = BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(AppRadius.pill),
    border: Border.all(color: AppColors.border),
    boxShadow: const [
      BoxShadow(
        color: AppColors.navShadowTablet,
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ],
  );

  /// Medidas do tablet (quadros "4c" e "4u").
  static const double tabletBottomHeight = 68;
  static const double tabletBottomItemHeight = 56;
  static const double railWidth = 88;
  static const double railItemSize = 64;

  /// O quadro "4u" desenha a barra com 68, borda de 1 e itens de 56: o recuo
  /// interno fica em 5 (o quadro diz 6, que não fecha a conta).
  Widget _buildTabletBottom() {
    return Container(
      height: tabletBottomHeight,
      padding: const EdgeInsets.all(AppSpacing.xs + 1),
      decoration: _tabletDecoration,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _buildTabletItem(
                items[i],
                i == currentIndex,
                () => onSelect(i),
                height: tabletBottomItemHeight,
                labelStyle: AppTypography.navLabelTabletBottom,
                label: items[i].label,
                // O badge começa 8 à direita do centro do item (quadro
                // "4u"): o centro dele fica 8 + 9 adiante.
                badge: (count) => Positioned(
                  top: AppSpacing.xs,
                  child: Transform.translate(
                    offset: const Offset(AppSpacing.sm + 9, 0),
                    child: _badge(count),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRail() {
    return Container(
      width: railWidth,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: _tabletDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: railItemSize,
              child: _buildTabletItem(
                items[i],
                i == currentIndex,
                () => onSelect(i),
                height: railItemSize,
                labelStyle: AppTypography.navLabel,
                label: items[i].shortLabel ?? items[i].label,
                badge: (count) => Positioned(
                  top: AppSpacing.sm - 2,
                  right: AppSpacing.sm,
                  child: _badge(count),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabletItem(
    PillNavItem item,
    bool isSelected,
    VoidCallback onTap, {
    required double height,
    required TextStyle labelStyle,
    required String label,
    required Widget Function(int count) badge,
  }) {
    final ink = isSelected ? AppColors.primaryDark : AppColors.text3;

    return Semantics(
      selected: isSelected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySurface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 23, color: ink),
                  const SizedBox(height: AppSpacing.xxs + 1),
                  Text(label, style: labelStyle.copyWith(color: ink)),
                ],
              ),
              if (item.badgeCount > 0) badge(item.badgeCount),
            ],
          ),
        ),
      ),
    );
  }

  /// O canvas do celular desenha o ativo em `accent` sobre o próprio tom e o
  /// inativo em `textMuted` (2,3:1 e 2,5:1); o app usa os tons do tablet, que
  /// passam de 4,5:1 (Fase 8C).
  Widget _buildItem(PillNavItem item, bool isSelected, VoidCallback onTap) {
    final ink = isSelected ? AppColors.primaryDark : AppColors.text3;

    return Semantics(
      selected: isSelected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySurface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 22, color: ink),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(item.label, style: AppTypography.navLabel.copyWith(color: ink)),
                ],
              ),
              if (item.badgeCount > 0) _buildBadge(item.badgeCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int count) {
    return Positioned(
      top: 4,
      child: Transform.translate(
        offset: const Offset(14, 0),
        child: _badge(count),
      ),
    );
  }

  Widget _badge(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.warningInkStrong,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.background, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: AppTypography.navLabel.copyWith(
          color: AppColors.surface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
