import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Botão principal do app: altura de 56, cantos de 12 e cor de marca.
///
/// Enquanto `isLoading`, o botão não responde ao toque mas mantém a cor cheia —
/// cinza de desabilitado só aparece quando não há ação disponível.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.controlHeight,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor:
              isLoading ? AppColors.primary : AppColors.borderStrong,
          disabledForegroundColor: AppColors.surface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button,
        ),
        child: isLoading ? _buildSpinner() : _buildContent(),
      ),
    );
  }

  Widget _buildSpinner() {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.surface),
      ),
    );
  }

  Widget _buildContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            style: AppTypography.button,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Botão secundário: mesma caixa do principal, contorno na cor de marca.
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.controlHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          disabledForegroundColor: AppColors.textMuted,
          side: BorderSide(
            color: onPressed == null ? AppColors.border : AppColors.primary,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                label,
                style: AppTypography.button.copyWith(color: AppColors.primaryDark),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tamanho do [AppCtaButton].
enum AppCtaSize {
  /// 48dp, texto 14 — ação dentro de uma linha de lista ("Atribuir a mim").
  compact,

  /// 56dp, texto 16 — ação principal isolada no rodapé ("Finalizar
  /// avaliação", quadro "1b").
  large,
}

/// Botão de chamada para ação em laranja. No tamanho `compact`, é a ação de
/// uma linha de lista, como "Atribuir a mim": o canvas o desenha com 36dp,
/// aqui ele tem 48dp, o alvo mínimo do DS (o consultor usa o app dentro do
/// veículo).
class AppCtaButton extends StatelessWidget {
  const AppCtaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.trailingIcon,
    this.size = AppCtaSize.compact,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  /// Ícone depois do rótulo — o "›" do "Próximo participante" (canvas "2g").
  final IconData? trailingIcon;
  final AppCtaSize size;

  bool get _large => size == AppCtaSize.large;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _large ? AppSpacing.controlHeight : AppSpacing.touchTarget,
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cta,
          foregroundColor: AppColors.ctaInk,
          disabledBackgroundColor: isLoading ? AppColors.cta : AppColors.border,
          disabledForegroundColor:
              isLoading ? AppColors.ctaInk : AppColors.textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          // A cor do `textStyle` não vale num botão — quem pinta o rótulo é o
          // `foregroundColor`. Daqui só saem o tamanho e o peso.
          textStyle: _large ? AppTypography.button : AppTypography.buttonCompact,
        ),
        child: isLoading ? _buildSpinner() : _buildContent(),
      ),
    );
  }

  Widget _buildSpinner() {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.ctaInk),
      ),
    );
  }

  Widget _buildContent() {
    // Sem `style` no `Text`: a cor vem do botão, e assim o rótulo fica cinza
    // junto com o fundo quando o botão está desabilitado (offline).
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: _large ? 22 : 19),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(trailingIcon, size: _large ? 25 : 21),
        ],
      ],
    );
  }
}

/// Ação destrutiva em contorno vermelho. No tamanho padrão, tem a caixa do
/// botão principal — "Cancelar sessão" (canvas "3b"): mora no fim da tela,
/// longe do salvar. Com [compact], é a ação de uma linha de lista — "Remover
/// da sessão" (canvas "3c"): o quadro a desenha com 44dp, aqui ela tem 48dp, o
/// alvo mínimo do DS.
class AppDangerOutlineButton extends StatelessWidget {
  const AppDangerOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final available = onPressed != null || isLoading;

    return SizedBox(
      height: compact ? AppSpacing.touchTarget : AppSpacing.controlHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.dangerInk,
          disabledForegroundColor:
              isLoading ? AppColors.dangerInk : AppColors.textMuted,
          side: BorderSide(
            color: available ? AppColors.dangerBorder : AppColors.border,
            width: 1.5,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.lg : AppSpacing.xl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              compact ? AppRadius.sm + 2 : AppRadius.md,
            ),
          ),
          // A cor vem do `foregroundColor`; daqui só o tamanho e o peso.
          textStyle:
              compact ? AppTypography.buttonCompact : AppTypography.buttonDanger,
        ),
        child: isLoading ? _buildSpinner() : _buildContent(),
      ),
    );
  }

  Widget _buildSpinner() {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.dangerInk),
      ),
    );
  }

  Widget _buildContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: compact ? 19 : 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// Ação em contorno cinza ao lado de um item de lista — o "Adicionar" da tela
/// "Consultores" (canvas "3c"). Tem a largura do rótulo, e não a da linha; o
/// quadro a desenha com 44dp, aqui ela tem 48dp, o alvo mínimo do DS.
class AppCompactOutlineButton extends StatelessWidget {
  const AppCompactOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final available = onPressed != null || isLoading;

    return SizedBox(
      height: AppSpacing.touchTarget,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          disabledForegroundColor:
              isLoading ? AppColors.primaryDark : AppColors.textMuted,
          backgroundColor: AppColors.surface,
          side: BorderSide(
            color: available ? AppColors.borderStrong : AppColors.border,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
          // A cor vem do `foregroundColor`; daqui só o tamanho e o peso.
          textStyle: AppTypography.buttonCompact,
        ),
        // O rótulo continua ocupando o lugar dele enquanto o indicador gira:
        // o botão tem a largura do conteúdo, e sem isso a linha pularia.
        child: Stack(
          alignment: Alignment.center,
          children: [
            Visibility(
              visible: !isLoading,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _buildContent(),
            ),
            if (isLoading) _buildSpinner(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpinner() {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
      ),
    );
  }

  Widget _buildContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 19),
          const SizedBox(width: AppSpacing.sm - AppSpacing.xxs),
        ],
        Text(label),
      ],
    );
  }
}

/// Tinta do [AppTextButton].
enum AppTextButtonTone {
  /// Cor de marca — uma segunda forma de concluir ("Salvar e adicionar outro").
  primary,

  /// Cinza — desistir ("Descartar").
  neutral,
}

/// Ação secundária em texto, sob o botão principal de um rodapé (canvas "3a"
/// e "3b"). Ocupa a largura toda, com o alvo mínimo de toque.
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.tone = AppTextButtonTone.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppTextButtonTone tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTarget,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: tone == AppTextButtonTone.primary
              ? AppColors.primaryDark
              : AppColors.text3,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.textAction,
        ),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Atalho de ícone: um alvo de toque inteiro (48dp) em volta de um ícone na
/// cor de marca — o lápis da barra superior e o "adicionar participante" do
/// detalhe da sessão (canvas "1f", que os desenha com 32dp). Sem ação, fica
/// apagado: as ações de ADMIN nunca somem, só desabilitam.
class AppIconAction extends StatelessWidget {
  const AppIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpacing.touchTarget,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 22),
        color: AppColors.primaryDark,
        disabledColor: AppColors.textMuted,
        onPressed: onPressed,
      ),
    );
  }
}
