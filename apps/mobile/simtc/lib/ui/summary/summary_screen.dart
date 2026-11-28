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
import '../core/widgets/app_footer_bar.dart';
import '../core/widgets/app_text_field.dart';
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

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Os campos de horário só mostram o que o viewmodel guarda; atualizar fora
    // do `build` evita mexer no controller no meio da construção do campo.
    _viewModel.addListener(_syncClockFields);
    _syncClockFields();
  }

  void _syncClockFields() {
    final start = _clockText(_viewModel.startTime);
    final end = _clockText(_viewModel.endTime);
    if (_startController.text != start) _startController.text = start;
    if (_endController.text != end) _endController.text = end;
  }

  /// "08:05" no horário local; sempre dois dígitos, mesmo em outro dia (o dia
  /// não se edita aqui).
  static String _clockText(DateTime? moment) {
    if (moment == null) return '';
    final local = moment.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _viewModel.removeListener(_syncClockFields);
    _startController.dispose();
    _endController.dispose();
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

  /// "2 infrações" ou, com observações do instrutor, "2 infrações · 1 obs.".
  String _countLabel(ChecklistCategory category) {
    final label = infractionCountLabel(category.markedCount);
    final observations = category.observationCount;
    return observations == 0 ? label : '$label · $observations obs.';
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
                    _countLabel(category),
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
      _countLabel(category),
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

    return AppFooterBar(
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
        _buildClockFields(),
        const SizedBox(height: AppSpacing.md),
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

  /// Início e fim da avaliação, lado a lado. Não se digita: o toque abre o
  /// seletor de hora (mesmo padrão do campo de data da edição da sessão). O erro
  /// de horário, se houver, aparece sob os dois campos.
  Widget _buildClockFields() {
    final enabled = !_viewModel.isConfirming;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                key: const Key('campo-inicio'),
                label: 'Início',
                controller: _startController,
                icon: AppIcons.time,
                readOnly: true,
                mono: true,
                enabled: enabled,
                onTap: () => _pickClock(
                  current: _viewModel.startTime,
                  helpText: 'Início da avaliação',
                  onPicked: _viewModel.setStartClock,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                key: const Key('campo-fim'),
                label: 'Fim',
                controller: _endController,
                icon: AppIcons.time,
                readOnly: true,
                mono: true,
                enabled: enabled,
                onTap: () => _pickClock(
                  current: _viewModel.endTime,
                  helpText: 'Fim da avaliação',
                  onPicked: _viewModel.setEndClock,
                ),
              ),
            ),
          ],
        ),
        // O erro vale para o par início/fim, e a coluna do Fim é estreita
        // demais para a frase: aparece uma vez, em largura total. O
        // `AppTextField` só marca a borda junto de um texto de erro, então os
        // campos ficam sem borda de erro.
        if (_viewModel.timesError case final error?) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            error,
            key: const Key('erro-horario'),
            style: AppTypography.meta.copyWith(color: AppColors.dangerInk),
          ),
        ],
        const SizedBox(height: AppSpacing.xs + 2),
        Text(
          'Ajuste se a avaliação começou ou terminou em outro horário: é o que sai no relatório.',
          style: AppTypography.meta,
        ),
      ],
    );
  }

  /// Seletor de hora em 24h, como o resto do app mostra os horários.
  Future<void> _pickClock({
    required DateTime? current,
    required String helpText,
    required void Function(int hour, int minute) onPicked,
  }) async {
    if (current == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current.toLocal()),
      helpText: helpText,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    onPicked(picked.hour, picked.minute);
  }
}
