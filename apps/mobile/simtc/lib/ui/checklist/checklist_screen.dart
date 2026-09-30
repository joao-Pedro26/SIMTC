import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../router.dart';
import '../core/score_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/skeleton.dart';
import '../summary/summary_screen.dart';
import 'checklist_badges.dart';
import 'checklist_sections.dart';
import 'checklist_viewmodel.dart';

/// Tela 1.5 — checklist da avaliação prática (Fase 4), quadro "1b" do canvas.
///
/// Tudo aqui é offline-first: cada toque num botão B/PM/M grava direto no
/// banco local (`ChecklistViewModel.toggleNote`), sem esperar rede — por isso
/// o "salvo" do cabeçalho não depende de conexão.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({
    super.key,
    required this.sessionId,
    required this.participantId,
  });

  final String sessionId;
  final String participantId;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  late final ChecklistViewModel _viewModel = ChecklistViewModel(
    sessionId: widget.sessionId,
    participantId: widget.participantId,
    // A rota só abre com sessão (redirecionamento do `router.dart`).
    ownerUserId: context.read<AuthRepository>().currentUser!.id,
    assessmentRepository: context.read<AssessmentRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    catalogRepository: context.read<AssessmentCatalogRepository>(),
  )..init();

  /// Cabeçalho da categoria aberta — há no máximo uma, então uma chave basta.
  final GlobalKey _openHeaderKey = GlobalKey();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            ConnectivityBanner(
              isOffline: isOffline,
              message: 'Sem conexão — as marcações continuam sendo salvas no aparelho.',
            ),
            Expanded(child: _buildBody()),
            if (!_viewModel.isLoading && _viewModel.hasCatalog) _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm + 2,
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: AppSpacing.touchTarget,
                child: IconButton(
                  tooltip: 'Voltar',
                  icon: const Icon(AppIcons.back, size: 30, color: AppColors.text),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _viewModel.participant?.name ?? '',
                      style: AppTypography.checklistParticipantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs - 1),
                    _buildTimerRow(),
                  ],
                ),
              ),
            ],
          ),
          if (!_viewModel.isLoading && _viewModel.hasCatalog && _viewModel.isStarted)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm + 2,
                AppSpacing.sm,
                0,
              ),
              child: _buildProgress(),
            ),
        ],
      ),
    );
  }

  Widget _buildTimerRow() {
    if (!_viewModel.isLoading && !_viewModel.isStarted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.timer, size: 14, color: AppColors.text3),
          const SizedBox(width: AppSpacing.xs),
          Text('não iniciada', style: AppTypography.meta),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(AppIcons.timer, size: 14, color: AppColors.text3),
        const SizedBox(width: AppSpacing.xs),
        Text(_viewModel.elapsedLabel, style: AppTypography.code),
        const SizedBox(width: AppSpacing.sm),
        Container(width: 1, height: 11, color: AppColors.borderStrong),
        const SizedBox(width: AppSpacing.sm),
        const Icon(AppIcons.syncDone, size: 14, color: AppColors.savedInk),
        const SizedBox(width: AppSpacing.xs),
        Text('salvo', style: AppTypography.savedLabel),
      ],
    );
  }

  Widget _buildProgress() {
    final reviewed = _viewModel.reviewedCount;
    final total = _viewModel.totalCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$reviewed de $total categorias revisadas',
                style: AppTypography.checklistProgress,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              percentLabel(_viewModel.overallScore),
              style: AppTypography.checklistProgressValue,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: total <= 0 ? 0 : reviewed / total,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return ListView(
        key: const Key('checklist-skeleton'),
        children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
      );
    }

    if (!_viewModel.hasCatalog) {
      return const Padding(
        key: Key('checklist-no-catalog'),
        padding: EdgeInsets.all(AppSpacing.xl),
        child: InlineNotice(
          icon: AppIcons.offline,
          tone: NoticeTone.warning,
          message: 'O catálogo de infrações ainda não foi baixado neste '
              'aparelho. Com internet, atualize a lista de sessões na Home — '
              'o catálogo desce junto.',
        ),
      );
    }

    if (!_viewModel.isStarted) return _buildNotStarted();

    // Como no canvas: a categoria aberta é um bloco próprio, e as fechadas
    // antes e depois dela formam grupos — cada bloco com borda em cima e
    // embaixo, separados por 10.
    final sections = _viewModel.sections;
    final open = sections.indexWhere((s) => s.id == _viewModel.expandedCategoryId);
    final before = open < 0 ? sections : sections.sublist(0, open);
    final after = open < 0 ? const <ChecklistCategory>[] : sections.sublist(open + 1);
    final blocks = [
      if (before.isNotEmpty) _buildCollapsedGroup(before),
      if (open >= 0) _buildExpandedCategory(sections[open]),
      if (after.isNotEmpty) _buildCollapsedGroup(after),
    ];

    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm + 2),
          blocks[i],
        ],
      ],
    );
  }

  /// Antes do "Iniciar avaliação" (decisão de 29/09/2026): o consultor pode ter
  /// aberto o participante sem querer — nada foi gravado, e voltar não deixa
  /// rastro. O canvas não tem este estado.
  Widget _buildNotStarted() {
    return Padding(
      key: const Key('checklist-not-started'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.huge,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        children: [
          const Icon(AppIcons.timer, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            'A avaliação ainda não começou.',
            style: AppTypography.cardTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'O cronômetro começa quando você tocar em "Iniciar avaliação".',
            style: AppTypography.meta,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedGroup(List<ChecklistCategory> categories) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final category in categories) _buildCollapsedCategory(category)],
      ),
    );
  }

  Widget _buildCollapsedCategory(ChecklistCategory category) {
    final count = category.infractions.length;

    return InkWell(
      key: ValueKey('category-${category.id}'),
      onTap: () => _openCategory(category.id),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
        ),
        child: Row(
          children: [
            CategoryCodeChip(code: category.code),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                category.name,
                style: AppTypography.categoryName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Text(count == 1 ? '1 item' : '$count itens', style: AppTypography.categoryCount),
            const SizedBox(width: AppSpacing.sm + 2),
            const Icon(AppIcons.expandMore, size: 22, color: AppColors.text3),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedCategory(ChecklistCategory category) {
    return DecoratedBox(
      key: ValueKey('category-${category.id}'),
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildExpandedHeader(category),
          for (final infraction in category.infractions) _buildInfractionRow(infraction),
        ],
      ),
    );
  }

  /// Abrir uma categoria fecha a que estava aberta; se ela ficava acima, a
  /// lista encolhe e o cabeçalho da recém-aberta sairia da tela. A lista rola
  /// até ele (decisão de 27/09/2026) — o consultor começa sempre pela
  /// primeira infração. Serve também para a volta da tela 1.6.
  void _openCategory(String categoryId) {
    _viewModel.expandCategory(categoryId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final header = _openHeaderKey.currentContext;
      if (header == null) return;
      Scrollable.ensureVisible(
        header,
        alignment: 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  Widget _buildExpandedHeader(ChecklistCategory category) {
    return InkWell(
      key: _openHeaderKey,
      onTap: () => _viewModel.toggleCategory(category.id),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: const BoxDecoration(
          color: AppColors.categoryExpandedBg,
          border: Border(bottom: BorderSide(color: AppColors.categoryExpandedBorder)),
        ),
        child: Row(
          children: [
            CategoryCodeChip(
              code: category.code,
              background: AppColors.primary,
              ink: AppColors.surface,
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                category.name,
                style: AppTypography.categoryName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            ScoreBadge(score: category.score),
            const SizedBox(width: AppSpacing.sm + 2),
            const Icon(AppIcons.expandLess, size: 22, color: AppColors.text3),
          ],
        ),
      ),
    );
  }

  Widget _buildInfractionRow(ChecklistInfraction infraction) {
    final comment = infraction.selectedComment;

    return Container(
      key: ValueKey('infraction-${infraction.id}'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // O número é o item na ficha oficial (`order`), não a posição
              // na lista — é por ele que a infração é achada numa contestação.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 14),
                child: Text('${infraction.order}', style: AppTypography.infractionNumber),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(infraction.description, style: AppTypography.infractionDescription),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              for (var i = 0; i < infraction.notes.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm - 2),
                Expanded(
                  child: _NoteButton(
                    note: infraction.notes[i],
                    selected: infraction.selectedNoteId == infraction.notes[i].id,
                    onTap: () => _viewModel.toggleNote(infraction.id, infraction.notes[i].id),
                  ),
                ),
              ],
            ],
          ),
          if (comment != null) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            _NoteComment(comment),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
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
      child: _viewModel.isStarted
          ? AppCtaButton(
              label: 'Finalizar avaliação',
              icon: AppIcons.finish,
              size: AppCtaSize.large,
              onPressed: _openSummary,
            )
          : AppCtaButton(
              label: 'Iniciar avaliação',
              icon: AppIcons.startEvaluation,
              size: AppCtaSize.large,
              isLoading: _viewModel.isStarting,
              onPressed: _viewModel.start,
            ),
    );
  }

  /// "Finalizar avaliação" abre a conferência (tela 1.6), sem o diálogo das
  /// categorias sem marcação da Fase 4: a 1.6 mostra cada categoria com o %
  /// antes do "Confirmar" (decisão de 29/09/2026). Quem põe na fila é o
  /// "Confirmar" de lá; daqui, só se decide para onde voltar.
  Future<void> _openSummary() async {
    final exit = await context.push<SummaryExit>(
      AppRoutes.participantSummary(widget.sessionId, widget.participantId),
    );
    if (!mounted) return;

    switch (exit) {
      case SummaryConfirmed():
        // Confirmada: o checklist sai também, de volta ao detalhe da sessão.
        await Navigator.of(context).maybePop();
      case SummaryReviewCategory(:final categoryId):
        _openCategory(categoryId);
      case null:
        break;
    }
  }
}

/// Um dos 3 botões B/PM/M (spec "4z"): raio 8, nunca pílula, para não se
/// confundir com os chips de status.
class _NoteButton extends StatelessWidget {
  const _NoteButton({required this.note, required this.selected, required this.onTap});

  final ChecklistNoteOption note;
  final bool selected;
  final VoidCallback onTap;

  ({Color bg, Color border, Color ink}) get _colors => switch (note.noteType) {
        'B' => selected
            ? (bg: AppColors.noteBFill, border: AppColors.noteBFill, ink: AppColors.noteBSelectedInk)
            : (bg: AppColors.noteBBg, border: AppColors.noteBBorder, ink: AppColors.noteBInk),
        'PM' => selected
            ? (bg: AppColors.notePmFill, border: AppColors.notePmFill, ink: AppColors.notePmSelectedInk)
            : (bg: AppColors.notePmBg, border: AppColors.notePmBorder, ink: AppColors.notePmInk),
        _ => selected
            ? (bg: AppColors.noteMFill, border: AppColors.noteMFill, ink: AppColors.noteMSelectedInk)
            : (bg: AppColors.noteMBg, border: AppColors.noteMBorder, ink: AppColors.noteMInk),
      };

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        height: AppSpacing.controlHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.bg,
          border: Border.all(color: colors.border, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(note.noteType, style: AppTypography.noteButton.copyWith(color: colors.ink)),
      ),
    );
  }
}

/// A observação da nota escolhida, abaixo dos botões (quadro "1b").
class _NoteComment extends StatelessWidget {
  const _NoteComment(this.comment);

  final String comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        border: Border.all(color: AppColors.warningBorder),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.notes, size: 16, color: AppColors.warningInk),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(comment, style: AppTypography.noteComment)),
        ],
      ),
    );
  }
}
