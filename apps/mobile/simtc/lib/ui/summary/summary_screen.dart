import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../checklist/checklist_badges.dart';
import '../checklist/checklist_sections.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/final_score_block.dart';
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
  /// A coluna da conferência no tablet em paisagem (quadro "4g").
  static const double expandedMaxWidth = 940;

  /// Largura do "Confirmar" no fim dessa coluna.
  static const double expandedCtaWidth = 420;

  /// Altura mínima da linha de categoria no tablet.
  static const double categoryMinHeightTablet = 76;

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

  bool get _ready => !_viewModel.isLoading && _viewModel.sections.isNotEmpty;

  Widget _buildScaffold() {
    // No tablet em paisagem, o "Confirmar" fica no fim da coluna (quadro
    // "4g"), e não há rodapé.
    final footer = _ready && !context.isExpandedLayout;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(title: 'Conferir e finalizar'),
            Expanded(child: _buildBody()),
            if (footer) _buildFooter(),
          ],
        ),
      ),
    );
  }

  /// No tablet, a conferência é uma coluna: de até 940, centrada, em
  /// paisagem (quadro "4g"); com 32 de recuo em retrato (quadro "4r").
  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return ListView(
        key: const Key('summary-skeleton'),
        children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
      );
    }

    final tablet = context.isTablet;
    final expanded = context.isExpandedLayout;
    final double inset = tablet ? 0 : AppSpacing.xl;
    final children = [
      _buildScore(),
      Padding(
        padding: EdgeInsets.fromLTRB(inset, AppSpacing.md + 3, inset, AppSpacing.md + 3),
        child: Text(
          'Por categoria',
          style: tablet
              ? AppTypography.summarySectionTitleTablet
              : AppTypography.summarySectionTitle,
        ),
      ),
      DecoratedBox(
        decoration: tablet
            ? const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
              )
            : const BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final category in _viewModel.sections) _buildCategory(category),
          ],
        ),
      ),
    ];

    if (expanded) {
      return ListView(
        // Em janelas de 840 a ~1040, a coluna não encosta nas bordas (o mesmo recuo do "não iniciada").
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.huge),
        children: [
          Center(
            child: ConstrainedBox(
              key: const Key('summary-column'),
              constraints: const BoxConstraints(maxWidth: expandedMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...children,
                  if (_ready)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xxl + 4, 0, AppSpacing.xxxl),
                      child: _buildActions(ctaWidth: expandedCtaWidth),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: tablet ? AppSpacing.xxxl : 0),
      children: children,
    );
  }

  Widget _buildScore() {
    final tablet = context.isTablet;
    return FinalScoreBlock(
      score: _viewModel.overallScore,
      approved: _viewModel.isApproved,
      details: [_detailLine(), if (_viewModel.timesLabel case final times?) times],
      scale: tablet ? FinalScoreScale.summaryTablet : FinalScoreScale.phone,
      padding: tablet
          ? const EdgeInsets.symmetric(vertical: AppSpacing.xxl)
          : const EdgeInsets.all(AppSpacing.xl),
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
    if (context.isTablet) return _buildTabletCategory(category);

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

  /// A linha de categoria no tablet (quadros "4g" e "4r"): 76 de altura
  /// mínima, 20 em cima e embaixo, divisórias de 1,5; o nome e as infrações
  /// lado a lado em paisagem e um embaixo do outro em retrato.
  Widget _buildTabletCategory(ChecklistCategory category) {
    final name = Text(
      category.name,
      style: AppTypography.categoryNameTablet,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final count = Text(
      infractionCountLabel(category.markedCount),
      style: AppTypography.summaryCountTablet,
    );

    return InkWell(
      key: ValueKey('summary-category-${category.id}'),
      onTap: () => Navigator.of(context).pop(SummaryReviewCategory(category.id)),
      child: Container(
        constraints: const BoxConstraints(minHeight: categoryMinHeightTablet),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5)),
        ),
        child: Row(
          children: [
            CategoryCodeChip(code: category.code),
            const SizedBox(width: AppSpacing.md + 2),
            Expanded(
              child: context.isExpandedLayout
                  ? Row(
                      children: [
                        Flexible(child: name),
                        const SizedBox(width: AppSpacing.md + 2),
                        count,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [name, const SizedBox(height: AppSpacing.xs), count],
                    ),
            ),
            const SizedBox(width: AppSpacing.md + 2),
            ScoreBadge(score: category.score),
            const SizedBox(width: AppSpacing.md + 2),
            const Icon(AppIcons.chevronRight, size: 22, color: AppColors.text3),
          ],
        ),
      ),
    );
  }

  /// O rodapé: no tablet em retrato, 16 em cima e embaixo e 32 dos lados
  /// (quadro "4r").
  Widget _buildFooter() {
    final tablet = context.isTablet;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: tablet
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl, vertical: AppSpacing.lg)
          : const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
      child: _buildActions(),
    );
  }

  /// O erro do "Confirmar" e o botão. Com [ctaWidth], o botão tem essa
  /// largura, alinhado à esquerda (quadro "4g").
  Widget _buildActions({double? ctaWidth}) {
    final error = _viewModel.errorMessage;
    final button = AppCtaButton(
      label: 'Confirmar',
      icon: AppIcons.check,
      size: context.isTablet ? AppCtaSize.tabletLarge : AppCtaSize.large,
      isLoading: _viewModel.isConfirming,
      onPressed: _viewModel.canConfirm ? _viewModel.confirm : null,
    );

    return Column(
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
        if (ctaWidth == null)
          button
        else
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: ctaWidth, child: button),
          ),
      ],
    );
  }
}
