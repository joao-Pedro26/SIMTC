import 'package:flutter/material.dart';

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
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
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
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: AppSpacing.sm - 1),
        _buildInput(),
        if (widget.errorText != null) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          _buildError(),
        ],
      ],
    );
  }

  Widget _buildLabel() {
    return Text(widget.label, style: AppTypography.fieldLabel);
  }

  Widget _buildInput() {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.controlHeight),
      decoration: BoxDecoration(
        color: widget.enabled ? AppColors.surface : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: _iconColor),
            const SizedBox(width: AppSpacing.sm + 2),
          ],
          Expanded(child: _buildTextField()),
          if (widget.onToggleObscure != null) _buildObscureToggle(),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: widget.obscureText
          ? AppTypography.passwordDots
          : AppTypography.fieldValue,
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
