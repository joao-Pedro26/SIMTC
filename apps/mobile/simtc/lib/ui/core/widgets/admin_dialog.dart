import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../form_factor.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Onde e com que tamanho cada janela de admin abre no tablet. Em paisagem,
/// ancorada à direita, a [top] do topo da área útil (quadros "4l", "4m" e
/// "4n"); em retrato, no centro, com 640 (quadros "4w", "4x" e "4y").
enum AdminDialogSize {
  addParticipant(width: 560, top: 80, maxHeight: 640),
  sessionEdit(width: 600, top: 68, maxHeight: 660),
  consultants(width: 600, top: 68, maxHeight: 660);

  const AdminDialogSize({
    required this.width,
    required this.top,
    required this.maxHeight,
  });

  /// Largura em paisagem.
  final double width;

  /// Distância do topo da área útil, em paisagem.
  final double top;

  /// Altura máxima em paisagem.
  final double maxHeight;

  /// Distância da borda direita, em paisagem.
  static const double right = 40;

  /// Largura em retrato.
  static const double portraitWidth = 640;

  /// Altura máxima em retrato.
  static const double portraitMaxHeight = 1000;
}

/// A rota de uma janela de admin no tablet: o fundo escurecido a 42% e a
/// janela por cima da tela de onde ela abriu. Tocar no fundo faz o mesmo que
/// o X e o voltar do Android — passa pelo `PopScope` da tela, que pergunta
/// antes de descartar o que foi preenchido (decisão de 23/10/2026).
class AdminDialogPage<T> extends Page<T> {
  const AdminDialogPage({super.key, required this.size, required this.child});

  final AdminDialogSize size;
  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return RawDialogRoute<T>(
      settings: this,
      barrierColor: AppColors.scrim,
      barrierLabel: 'Fechar',
      pageBuilder: (context, animation, secondaryAnimation) =>
          AdminDialogLayout(size: size, child: child),
    );
  }
}

/// Põe a janela no lugar: ancorada à direita em paisagem, no centro em
/// retrato. Com o teclado aberto, ela encolhe para caber acima dele, e o
/// conteúdo rola.
class AdminDialogLayout extends StatelessWidget {
  const AdminDialogLayout({super.key, required this.size, required this.child});

  final AdminDialogSize size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final available = media.size.height -
        media.viewInsets.bottom -
        media.padding.top -
        media.padding.bottom;
    final expanded = context.isExpandedLayout;

    // A mesma árvore nas duas posições: girar com a janela aberta não pode
    // recriar a tela de dentro (o que foi digitado).
    final EdgeInsets padding;
    final double width;
    final double maxHeight;
    if (expanded) {
      padding = EdgeInsets.only(
        top: media.padding.top + size.top,
        right: AdminDialogSize.right,
      );
      width = size.width;
      maxHeight = math.min(size.maxHeight, available - size.top - AppSpacing.xxl);
    } else {
      padding = EdgeInsets.only(
        top: media.padding.top,
        bottom: media.viewInsets.bottom + media.padding.bottom,
      );
      width = math.min(
        AdminDialogSize.portraitWidth,
        media.size.width - 2 * AppSpacing.lg,
      );
      maxHeight = math.min(
        AdminDialogSize.portraitMaxHeight,
        available - 2 * AppSpacing.xxl,
      );
    }

    return Padding(
      padding: padding,
      child: Align(
        alignment: expanded ? Alignment.topRight : Alignment.center,
        child: SizedBox(
          width: width,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: math.max(0, maxHeight)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A janela de admin do tablet: cabeçalho com título, subtítulo e o X; o
/// conteúdo, que rola; e o rodapé, quando há (quadros "4l", "4m" e "4n").
/// A janela tem a altura do conteúdo, até o limite do [AdminDialogLayout].
class AdminDialogFrame extends StatelessWidget {
  const AdminDialogFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.body,
    this.banner,
    this.footer,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  /// O conteúdo. Uma lista aqui dentro precisa de `shrinkWrap`.
  final Widget body;

  /// A faixa de sem conexão, embaixo do cabeçalho.
  final Widget? banner;
  final Widget? footer;

  /// Canto da janela.
  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('admin-dialog'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.dialogShadow,
            offset: Offset(0, AppSpacing.xxl),
            blurRadius: 64,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            if (banner != null) banner!,
            Flexible(child: body),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }

  /// 18 em cima, 16 embaixo, 24 dos lados; o X sobe 10 e avança 10, para o
  /// ícone ficar alinhado com o título e a margem.
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg + 2,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTypography.dialogTitle),
                const SizedBox(height: AppSpacing.xxs + 1),
                // Uma linha em paisagem (quadro "4l"); quebra em retrato
                // (quadro "4w").
                Text(
                  subtitle,
                  style: AppTypography.dialogSubtitle,
                  maxLines: context.isExpandedLayout ? 1 : null,
                  overflow: context.isExpandedLayout ? TextOverflow.ellipsis : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Transform.translate(
            offset: const Offset(AppSpacing.sm + 2, -(AppSpacing.sm + 2)),
            child: SizedBox.square(
              dimension: AppSpacing.touchTarget,
              child: IconButton(
                tooltip: 'Fechar',
                icon: const Icon(AppIcons.close, size: 24, color: AppColors.text3),
                onPressed: onClose,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// O rodapé de uma janela de admin: o erro, quando há; numa linha, a ação
/// secundária à esquerda e a principal à direita; e o motivo de a principal
/// estar apagada, embaixo. Fundo cinza-claro, 14 em cima, 18 embaixo e 24
/// dos lados (quadros "4l" e "4m").
class AdminDialogFooter extends StatelessWidget {
  const AdminDialogFooter({
    super.key,
    required this.secondary,
    required this.primary,
    this.notice,
    this.caption,
  });

  final Widget secondary;
  final Widget primary;
  final Widget? notice;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.md + 2,
        AppSpacing.xxl,
        AppSpacing.lg + 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null) ...[notice!, const SizedBox(height: AppSpacing.sm)],
          Row(
            children: [
              Expanded(child: secondary),
              const SizedBox(width: AppSpacing.md),
              primary,
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(caption, style: AppTypography.meta, textAlign: TextAlign.end),
          ],
        ],
      ),
    );
  }
}
