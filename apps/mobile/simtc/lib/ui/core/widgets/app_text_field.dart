import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Campo de texto do Design System: rótulo acima, ícone à esquerda, borda que
/// reage a foco e erro, e ação opcional à direita (ex.: mostrar/ocultar senha).
///
/// Componente sem regra de negócio — recebe estado e devolve eventos.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.hintText,
    this.errorText,
    this.helperText,
    this.labelTrailing,
    this.trailing,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.minLines,
    this.maxLines = 1,
    this.mono = false,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final String? hintText;
  final String? errorText;

  /// Texto de apoio sob o campo ("CPF válido e sem cadastro nesta sessão.").
  /// O [errorText], quando existe, toma o lugar dele.
  final String? helperText;

  /// Nota discreta à direita do rótulo ("opcional").
  final String? labelTrailing;

  /// Widget à direita do texto, dentro da caixa — o check do CPF válido, o
  /// indicador de consulta.
  final Widget? trailing;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  /// Campo que não se digita: o toque em qualquer ponto da caixa chama
  /// [onTap] (a data, que abre o calendário) e o teclado não abre.
  final bool readOnly;
  final VoidCallback? onTap;

  /// Mais de uma linha (as observações). `maxLines: null` cresce sem limite.
  final int? minLines;
  final int? maxLines;

  /// Valor na fonte de números (o CPF).
  final bool mono;
  final List<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _internalFocusNode;
  bool _isFocused = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  bool get _isMultiline => widget.maxLines != 1;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  Color get _borderColor {
    if (widget.errorText != null) return AppColors.dangerInk;
    if (_isFocused) return AppColors.primary;
    return AppColors.borderStrong;
  }

  Color get _iconColor {
    if (widget.errorText != null) return AppColors.dangerInk;
    if (_isFocused) return AppColors.primary;
    return AppColors.text3;
  }

  @override
  Widget build(BuildContext context) {
    final helperText = widget.helperText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: AppSpacing.sm - 1),
        _buildInput(),
        if (widget.errorText != null) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          _buildError(),
        ] else if (helperText != null) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          Text(helperText, style: AppTypography.meta),
        ],
      ],
    );
  }

  Widget _buildLabel() {
    final label = Text(widget.label, style: AppTypography.fieldLabel);
    final trailing = widget.labelTrailing;
    if (trailing == null) return label;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: label),
        Text(trailing, style: AppTypography.fieldOptional),
      ],
    );
  }

  Widget _buildInput() {
    final trailing = widget.trailing;
    final box = Container(
      constraints: BoxConstraints(
        minHeight:
            _isMultiline ? AppSpacing.huge * 2 : AppSpacing.controlHeight,
      ),
      decoration: BoxDecoration(
        color: widget.enabled ? AppColors.surface : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: _borderColor, width: 1),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 2,
        vertical: _isMultiline ? AppSpacing.md : 0,
      ),
      child: Row(
        crossAxisAlignment: _isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: _iconColor),
            const SizedBox(width: AppSpacing.sm + 2),
          ],
          Expanded(child: _buildTextField()),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing,
          ],
          if (widget.onToggleObscure != null) _buildObscureToggle(),
        ],
      ),
    );
    if (!widget.readOnly) return box;

    // Só leitura: a caixa inteira é o alvo do toque, e o campo de dentro não
    // recebe o ponteiro — assim o teclado nunca abre.
    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: IgnorePointer(child: box),
      ),
    );
  }

  TextStyle get _valueStyle {
    if (widget.obscureText) return AppTypography.passwordDots;
    return widget.mono ? AppTypography.fieldValueMono : AppTypography.fieldValue;
  }

  Widget _buildTextField() {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: _valueStyle,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: widget.hintText,
        hintStyle: AppTypography.fieldValue.copyWith(color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildObscureToggle() {
    return Semantics(
      button: true,
      label: widget.obscureText ? 'Mostrar senha' : 'Ocultar senha',
      child: InkWell(
        onTap: widget.onToggleObscure,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // A área de toque é o tamanho do filho: um ícone de 22 com padding
        // pequeno daria ~38 dp, abaixo do mínimo de 48 dp exigido para uso com
        // o veículo em movimento.
        child: SizedBox(
          width: AppSpacing.touchTarget,
          height: AppSpacing.touchTarget,
          child: Center(
            child: Icon(
              widget.obscureText ? AppIcons.showPassword : AppIcons.hidePassword,
              size: 22,
              color: AppColors.text3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Text(
      widget.errorText!,
      style: AppTypography.meta.copyWith(color: AppColors.dangerInk),
    );
  }
}
