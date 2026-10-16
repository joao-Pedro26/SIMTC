import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/inline_notice.dart';

/// Uma linha da tela 1.13 "Consultores" (canvas "3c"): o nome, uma linha de
/// apoio e, à direita, o papel de quem está na sessão ou o "Adicionar" de
/// quem está na equipe. Quem está na sessão ainda pode ter o aviso da
/// avaliação em andamento e o "Remover da sessão".
///
/// Arquivo próprio por tamanho, não por reuso, como o `participant_row.dart`.
class ConsultantRow extends StatelessWidget {
  const ConsultantRow({
    super.key,
    required this.name,
    required this.trailing,
    this.meta,
    this.metaWraps = false,
    this.note,
    this.action,
  });

  final String name;

  /// A pastilha do papel, ou o botão "Adicionar".
  final Widget trailing;

  /// "2 participantes · 1 em andamento" de quem está na sessão; o e-mail de
  /// quem está na equipe.
  final String? meta;

  /// A linha de apoio quebra em vez de encolher com reticências. O quadro só
  /// corta a de quem está na equipe (o e-mail); a de quem está na sessão é
  /// informação, e aparece inteira.
  final bool metaWraps;

  /// O que acontece com a avaliação em andamento se o consultor sair.
  final String? note;

  /// "Remover da sessão" — o responsável não tem.
  final Widget? action;

  // O vão entre o cabeçalho, o aviso e a ação (10 no canvas).
  static const double _gap = AppSpacing.md - AppSpacing.xxs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg - 1,
      ),
      // O quadro desenha o contorno em cima e embaixo de cada linha: entre
      // duas linhas seguidas, os dois se somam.
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1.5),
          bottom: BorderSide(color: AppColors.border, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          if (note != null) ...[
            const SizedBox(height: _gap),
            InlineNotice(
              icon: AppIcons.info,
              tone: NoticeTone.warning,
              message: note!,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: _gap),
            action!,
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(child: _buildIdentity()),
        const SizedBox(width: AppSpacing.md),
        trailing,
      ],
    );
  }

  Widget _buildIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: AppTypography.consultantName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (meta != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            meta!,
            style: AppTypography.meta,
            maxLines: metaWraps ? null : 1,
            overflow: metaWraps ? null : TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
