import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../checklist/checklist_badges.dart';
import '../checklist/checklist_sections.dart';
import '../core/score_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/skeleton.dart';
import 'summary_viewmodel.dart';

/// Como a tela 1.6 fechou — o checklist, que a abriu, decide o que fazer.
sealed class SummaryExit {
  const SummaryExit();
}

/// "Confirmar": a avaliação entrou na fila. O checklist fecha também.
final class SummaryConfirmed extends SummaryExit {
  const SummaryConfirmed();
}

/// Tocou numa categoria: o checklist abre nela, para o consultor corrigir.
final class SummaryReviewCategory extends SummaryExit {
  const SummaryReviewCategory(this.categoryId);

  final String categoryId;
}

/// Tela 1.6 — "Conferir e finalizar" (quadro "2e" do canvas, adaptado ao
/// cálculo real em 29/09/2026: sem a conta de pontos, com o selo de % de cada
/// categoria e sem a etapa de assinatura).
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.participantId});

  final String participantId;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late final SummaryViewModel _viewModel = SummaryViewModel(
    participantId: widget.participantId,
    assessmentRepository: context.read<AssessmentRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    catalogRepository: context.read<AssessmentCatalogRepository>(),
  )..init();

  bool _closing = false;

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        if (_viewModel.isConfirmed && !_closing) {
          _closing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop(const SummaryConfirmed());
          });
        }
        return _buildScaffold();
      },
    );
  }

  Widget _buildScaffold() {
    final ready = !_viewModel.isLoading && _viewModel.sections.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(title: 'Conferir e finalizar'),
            Expanded(child: _buildBody()),
            if (ready) _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return ListView(
        key: const Key('summary-skeleton'),
        children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
      );
    }

    return ListView(
      children: [
        _buildScore(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md + 3,
            AppSpacing.xl,
            AppSpacing.md + 3,
          ),
          child: Text('Por categoria', style: AppTypography.summarySectionTitle),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final category in _viewModel.sections) _buildCategory(category),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScore() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pontuação final', style: AppTypography.summaryScoreLabel),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      percentLabel(_viewModel.overallScore),
                      style: AppTypography.summaryScore,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _ResultPill(approved: _viewModel.isApproved),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 2),
          Text(_detailLine(), style: AppTypography.summaryDetail),
        ],
      ),
    );
  }

  /// "Ana Paula Ribeiro · 3 infrações · mínimo para aprovação 70%."
  String _detailLine() {
    final name = _viewModel.participant?.name ?? '';
    final count = _viewModel.infractionCount;
    return [
      if (name.isNotEmpty) name,
      count == 0 ? 'nenhuma infração' : infractionCountLabel(count),
      'mínimo para aprovação 70%.',
    ].join(' · ');
  }

  Widget _buildCategory(ChecklistCategory category) {
    return InkWell(
      key: ValueKey('summary-category-${category.id}'),
      onTap: () => Navigator.of(context).pop(SummaryReviewCategory(category.id)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
        ),
        child: Row(
          children: [
            CategoryCodeChip(code: category.code),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: AppTypography.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs + 1),
                  Text(
                    infractionCountLabel(category.markedCount),
                    style: AppTypography.meta,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ScoreBadge(score: category.score),
            const SizedBox(width: AppSpacing.sm),
            const Icon(AppIcons.chevronRight, size: 22, color: AppColors.text3),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final error = _viewModel.errorMessage;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null) ...[
            InlineNotice(
              icon: AppIcons.needsReview,
              tone: NoticeTone.danger,
              message: error,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppCtaButton(
            label: 'Confirmar',
            icon: AppIcons.check,
            size: AppCtaSize.large,
            isLoading: _viewModel.isConfirming,
            onPressed: _viewModel.canConfirm ? _viewModel.confirm : null,
          ),
        ],
      ),
    );
  }
}

/// "Aprovado" ou "Necessita reavaliação", ao lado do % — o corte de 70% do
/// backend. As cores são as dos chips de status do detalhe da sessão.
class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.approved});

  final bool approved;

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, border, ink) = approved
        ? (
            'Aprovado',
            AppIcons.approved,
            AppColors.successBg,
            AppColors.successBorder,
            AppColors.successInk,
          )
        : (
            'Necessita reavaliação',
            AppIcons.needsReview,
            AppColors.dangerBg,
            AppColors.dangerBorder,
            AppColors.dangerInk,
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm + 2,
        AppSpacing.xs + 2,
        AppSpacing.md,
        AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ink),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(label, style: AppTypography.resultPill.copyWith(color: ink)),
        ],
      ),
    );
  }
}
