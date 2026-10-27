import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/services/assessment_sync_service.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/local/app_database.dart';
import '../../router.dart';
import '../core/form_factor.dart';
import '../core/text_scale.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_nav_bar.dart';
import '../core/widgets/status_chip.dart';
import 'sync_queue_labels.dart';

/// Tela 1.9 — aba "Sincronizar" (quadro "2h" do canvas, Fase 5A).
///
/// Mostra a fila de envio do consultor logado. O envio é automático; os
/// botões "Sincronizar agora" e "Tentar novamente" só adiantam a próxima
/// tentativa (decisão de 29/09/2026), e o "Descartar" tira da fila o que o
/// servidor recusou (decisão de 01/10/2026). Não tem ViewModel própria: o
/// estado é todo do `AssessmentSyncService`, que o app inteiro compartilha, e
/// as regras de texto estão em `sync_queue_labels.dart`.
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key, this.clock});

  /// Relógio injetável para os testes; o padrão é `DateTime.now`.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<AssessmentSyncService>();
    final isOffline = context.watch<ConnectivityService>().isOffline;
    final now = (clock ?? DateTime.now)();
    final queue = sync.queue;
    final tablet = context.isTablet;
    final content = Column(
      children: [
        _buildHeader(sync, now, tablet: tablet),
        Expanded(
          child: _buildList(context, sync, queue, isOffline, now, tablet: tablet),
        ),
      ],
    );

    // É uma aba, não uma tela empilhada: o voltar do Android leva para
    // Sessões, em vez de fechar o app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: TabSnackBarArea(
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: tablet
                ? TabletNavFrame(current: AppTab.sync, child: content)
                : content,
          ),
          bottomNavigationBar:
              tablet ? null : const AppNavBar(current: AppTab.sync),
        ),
      ),
    );
  }

  /// No tablet (quadros "4j" e "4u"), a fila fica numa coluna de no máximo
  /// 820 de texto, centrada — os itens trazem os próprios 20 de recuo, por
  /// isso a coluna tem 860 e nunca menos de 4 de margem (24 no total, o
  /// recuo do quadro em retrato).
  static const double _tabletColumnWidth = 860;

  Widget _buildList(
    BuildContext context,
    AssessmentSyncService sync,
    List<LocalAssessment> queue,
    bool isOffline,
    DateTime now, {
    required bool tablet,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = tablet
            ? math.max(
                AppSpacing.xs,
                (constraints.maxWidth - _tabletColumnWidth) / 2,
              )
            : 0.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            side,
            tablet ? AppSpacing.xl : AppSpacing.lg,
            side,
            tablet ? AppSpacing.xxl + AppSpacing.xs : AppSpacing.lg,
          ),
          children: [
            if (isOffline && queue.isNotEmpty) _buildOfflineCard(queue.length),
            if (queue.isEmpty)
              _buildEmpty()
            else
              _buildQueue(context, sync, queue, isOffline, now),
            _buildSyncNow(sync, queue, isOffline),
          ],
        );
      },
    );
  }

  /// Tablet: 14 em cima e embaixo, 24 dos lados, título de 24 e linha de
  /// 13,5 (quadros "4j" e "4u").
  Widget _buildHeader(
    AssessmentSyncService sync,
    DateTime now, {
    required bool tablet,
  }) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: tablet
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.md + 2,
            )
          : const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm + 2,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Sincronizar',
              style: tablet ? AppTypography.homeTitle : AppTypography.screenTitle,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            lastSyncLabel(sync.lastSyncedAt, now),
            style: tablet
                ? AppTypography.screenSubtitleTablet
                : AppTypography.screenSubtitle,
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineCard(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
      child: Container(
        key: const Key('sync-offline-card'),
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.warningBorder, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(AppIcons.offline, size: 26, color: AppColors.warningInk),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(queueCountLabel(count), style: AppTypography.queueNoticeTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Sem conexão agora. Nada é perdido: a fila sobe sozinha '
                    'quando o sinal voltar.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.noteCommentInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fila vazia — o canvas não desenha este estado (aprovado em 29/09/2026).
  Widget _buildEmpty() {
    return Padding(
      key: const Key('sync-empty'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          const Icon(AppIcons.syncDone, size: 40, color: AppColors.successInk),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nenhuma avaliação na fila',
            style: AppTypography.cardTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tudo o que você confirmou já chegou ao servidor.',
            style: AppTypography.meta,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQueue(
    BuildContext context,
    AssessmentSyncService sync,
    List<LocalAssessment> queue,
    bool isOffline,
    DateTime now,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md + 3,
            AppSpacing.xl,
            AppSpacing.md + 3,
          ),
          child: Semantics(
            header: true,
            child: Text('Pendentes', style: AppTypography.sectionTitle),
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in queue) _buildItem(context, sync, item, isOffline, now),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItem(
    BuildContext context,
    AssessmentSyncService sync,
    LocalAssessment item,
    bool isOffline,
    DateTime now,
  ) {
    final state = queueItemStateOf(item, sending: sync.isSendingItem(item.id));

    return Container(
      key: ValueKey('sync-item-${item.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md + 3,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      queueItemTitle(item),
                      style: AppTypography.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs + 1),
                    Text(queueItemMeta(item, state, now), style: AppTypography.meta),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _buildPill(state),
            ],
          ),
          if (state == QueueItemState.failed) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            _buildFailedActions(context, sync, item, isOffline),
          ],
        ],
      ),
    );
  }

  /// "Tentar novamente" e, só no que o servidor recusou, "Descartar" — falha
  /// de rede ou de servidor continua tentando sozinha.
  Widget _buildFailedActions(
    BuildContext context,
    AssessmentSyncService sync,
    LocalAssessment item,
    bool isOffline,
  ) {
    final retry = _RetryButton(
      onPressed: isOffline || sync.isSending ? null : sync.syncNow,
    );
    if (!SendFailure.refusals.contains(item.lastError)) return retry;

    final discard = _DiscardButton(
      onPressed: sync.isSending ? null : () => _confirmDiscard(context, sync, item),
    );

    // Lado a lado só onde os dois cabem com o texto numa linha (o tablet);
    // no celular, "Tentar novamente" quebrava em duas linhas: um embaixo do
    // outro, cada um na largura inteira (Fase 8C).
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth / context.textScale >= _sideBySideMinWidth) {
          return Row(
            children: [
              Expanded(child: retry),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: discard),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [retry, const SizedBox(height: AppSpacing.sm), discard],
        );
      },
    );
  }

  /// A largura (na fonte normal) a partir da qual "Tentar novamente" e
  /// "Descartar" cabem lado a lado, cada um com o texto numa linha.
  static const double _sideBySideMinWidth = 480;

  Future<void> _confirmDiscard(
    BuildContext context,
    AssessmentSyncService sync,
    LocalAssessment item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar a avaliação?'),
        content: Text(
          'A avaliação de ${queueItemTitle(item)} não foi aceita pelo servidor '
          'e será apagada deste aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    var discarded = false;
    try {
      discarded = await sync.discardRefused(item.id);
    } catch (_) {
      // Uma falha do banco local cai no mesmo aviso de quando o serviço não
      // apaga — sem isto, viraria uma exceção solta no toque do botão.
    }
    if (discarded || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível descartar. Tente de novo.')),
    );
  }

  Widget _buildPill(QueueItemState state) {
    return switch (state) {
      QueueItemState.queued => const StatusChip(
          label: 'Na fila',
          icon: AppIcons.pending,
          tone: StatusTone.neutral,
        ),
      QueueItemState.sending => const StatusChip(
          label: 'Enviando',
          icon: AppIcons.sync,
          tone: StatusTone.info,
        ),
      QueueItemState.failed => const StatusChip(
          label: 'Erro',
          icon: AppIcons.sendFailed,
          tone: StatusTone.danger,
        ),
    };
  }

  Widget _buildSyncNow(
    AssessmentSyncService sync,
    List<LocalAssessment> queue,
    bool isOffline,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCtaButton(
            label: 'Sincronizar agora',
            icon: AppIcons.sync,
            size: AppCtaSize.large,
            isLoading: sync.isSending,
            onPressed: isOffline || queue.isEmpty ? null : sync.syncNow,
          ),
          if (isOffline) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Text(
              'Disponível quando houver conexão',
              style: AppTypography.meta,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Descartar" de um item que o servidor recusou (decisão de 01/10/2026 — não
/// está no canvas): o formato do "Tentar novamente", em vermelho.
class _DiscardButton extends StatelessWidget {
  const _DiscardButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTarget,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(AppIcons.discard, size: 19),
        label: const Text('Descartar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.dangerInk,
          disabledForegroundColor: AppColors.textMuted,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.dangerBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
          textStyle: AppTypography.buttonCompact,
        ),
      ),
    );
  }
}

/// "Tentar novamente" de um item com erro (canvas "2h"): contorno neutro, com
/// 48dp — o alvo mínimo do DS, como o "Atribuir a mim" (o canvas tem 44).
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTarget,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(AppIcons.retry, size: 19),
        label: const Text('Tentar novamente'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text2,
          disabledForegroundColor: AppColors.textMuted,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
          textStyle: AppTypography.buttonCompact,
        ),
      ),
    );
  }
}
