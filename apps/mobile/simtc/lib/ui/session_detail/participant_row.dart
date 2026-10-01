import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// Uma linha da lista de participantes da tela 1.4: nome, CPF mascarado,
/// chip de situação e, conforme o caso, o horário da avaliação, a nota de
/// bloqueio ou o botão "Atribuir a mim".
///
/// Arquivo próprio por tamanho, não por reuso: embutida na tela, ela
/// atrapalharia a leitura do `build()` (convenção do `login_screen.dart`).
class ParticipantRow extends StatelessWidget {
  const ParticipantRow({
    super.key,
    required this.name,
    required this.maskedCpf,
    required this.chip,
    this.meta,
    this.blockedNote,
    this.action,
    this.onTap,
    this.accentColor = AppColors.border,
    this.muted = false,
  });

  final String name;
  final String maskedCpf;
  final Widget chip;

  /// "hoje 08:12" dos concluídos, "Iniciada às 08:12" do rascunho,
  /// "86,7% · aguardando envio" de quem está na fila.
  final String? meta;

  /// Por que a linha não tem ação ("Em avaliação com outro consultor.").
  final String? blockedNote;

  /// Botão sob a linha — hoje, só o "Atribuir a mim".
  final Widget? action;

  /// Nulo = a linha não abre nada, e o chevron some.
  final VoidCallback? onTap;

  /// Traço superior, na cor da situação.
  final Color accentColor;

  /// Fundo apagado para quem está com outro consultor.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg - 1,
        ),
        decoration: BoxDecoration(
          color: muted ? AppColors.background : AppColors.surface,
          border: Border(top: BorderSide(color: accentColor, width: 0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            if (blockedNote != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(blockedNote!, style: AppTypography.meta),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(child: _buildIdentity()),
        const SizedBox(width: AppSpacing.md),
        chip,
        if (onTap != null) ...[
          const SizedBox(width: AppSpacing.xs),
          const Icon(AppIcons.chevronRight, size: 24, color: AppColors.text3),
        ],
      ],
    );
  }

  Widget _buildIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: AppTypography.cardTitle.copyWith(
            color: muted ? AppColors.text2 : AppColors.text,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(maskedCpf, style: AppTypography.code),
        if (meta != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(meta!, style: AppTypography.meta),
        ],
      ],
    );
  }
}
