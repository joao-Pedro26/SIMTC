import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_text_field.dart';

/// Campo de escolha do Design System: o visual do [AppTextField] (rótulo
/// acima, mesma caixa e bordas) com uma seta à direita; tocar abre um menu
/// ancorado no campo, com uma opção por item.
///
/// Componente sem regra de negócio — recebe o valor e devolve a escolha.
///
/// Reaproveita o [AppTextField] em modo só leitura (a caixa inteira é o alvo
/// do toque, o teclado nunca abre e o leitor de tela ganha um nó só), em vez
/// de repetir o desenho da caixa; o controller só guarda o texto da opção.
class AppSelectField<T> extends StatefulWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.hintText,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<T> options;
  final String Function(T) optionLabel;
  final ValueChanged<T> onChanged;
  final String? hintText;
  final IconData? icon;
  final bool enabled;

  @override
  State<AppSelectField<T>> createState() => _AppSelectFieldState<T>();
}

class _AppSelectFieldState<T> extends State<AppSelectField<T>> {
  final MenuController _menu = MenuController();
  late final TextEditingController _controller =
      TextEditingController(text: _textOf(widget.value));

  String _textOf(T? value) => value == null ? '' : widget.optionLabel(value);

  @override
  void didUpdateWidget(AppSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = _textOf(widget.value);
    if (_controller.text != text) _controller.text = text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() => _menu.isOpen ? _menu.close() : _menu.open();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : null;
        return MenuAnchor(
          controller: _menu,
          // O menu tem a largura do campo, e não a do conteúdo.
          style: MenuStyle(
            backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
            minimumSize: width == null
                ? null
                : WidgetStatePropertyAll(Size(width, 0)),
            maximumSize: width == null
                ? null
                : WidgetStatePropertyAll(Size(width, double.infinity)),
          ),
          menuChildren: [
            for (final option in widget.options)
              MenuItemButton(
                style: MenuItemButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md + 2,
                  ),
                ),
                onPressed: () => widget.onChanged(option),
                child: Text(
                  widget.optionLabel(option),
                  style: option == widget.value
                      ? AppTypography.fieldValue
                          .copyWith(fontWeight: FontWeight.w700)
                      : AppTypography.fieldValue,
                ),
              ),
          ],
          child: AppTextField(
            label: widget.label,
            controller: _controller,
            icon: widget.icon,
            hintText: widget.hintText,
            enabled: widget.enabled,
            readOnly: true,
            onTap: _toggle,
            trailing: Icon(
              AppIcons.chevronDown,
              size: 22,
              color: widget.enabled ? AppColors.text3 : AppColors.textMuted,
            ),
          ),
        );
      },
    );
  }
}
