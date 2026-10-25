import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A lupa das listas (canvas "2c", "1e"/"1f" e "3c"): um alvo de 48 com o
/// ícone em cinza. O detalhe da sessão a desenha com ícone de 19, ao lado dos
/// filtros; a Home e Consultores, com 22.
class AppSearchButton extends StatelessWidget {
  const AppSearchButton({
    super.key,
    required this.onPressed,
    this.iconSize = defaultIconSize,
  });

  final VoidCallback onPressed;
  final double iconSize;

  static const double defaultIconSize = 22;

  /// O tamanho do ícone na barra dos filtros do detalhe (quadros "1e", "1f").
  static const double filtersIconSize = 19;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpacing.touchTarget,
      child: IconButton(
        tooltip: 'Buscar',
        icon: Icon(AppIcons.search, size: iconSize),
        color: AppColors.text3,
        onPressed: onPressed,
      ),
    );
  }
}

/// O campo que a lupa abre (Fase 8B — o canvas só desenha a lupa): o ícone de
/// busca, o texto e o X que fecha a busca. Tem 48 de altura e abre com o
/// teclado à mostra. Guarda o próprio texto: começa com [initialText] e avisa
/// cada mudança em [onChanged].
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    required this.onClose,
    this.initialText = '',
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final String initialText;

  static const double _iconSize = 20;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    );

    return SizedBox(
      height: AppSpacing.touchTarget,
      child: TextField(
        controller: _controller,
        autofocus: true,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: AppTypography.fieldValue,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTypography.fieldValue.copyWith(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surface,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
          prefixIcon: const Icon(
            AppIcons.search,
            size: AppSearchField._iconSize,
            color: AppColors.text3,
          ),
          suffixIcon: IconButton(
            tooltip: 'Fechar a busca',
            icon: const Icon(AppIcons.close, size: AppSearchField._iconSize),
            color: AppColors.text3,
            onPressed: widget.onClose,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}
