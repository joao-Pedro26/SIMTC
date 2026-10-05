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
    consultantId: context.read<AuthRepository>().currentUser!.consultantId,
    assessmentRepository: context.read<AssessmentRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    catalogRepository: context.read<AssessmentCatalogRepository>(),
  )..init();

  /// Cabeçalho da categoria aberta — há no máximo uma, então uma chave basta.
  final GlobalKey _openHeaderKey = GlobalKey();

  /// Um desatribuir (que espera o backend) ou um descarte no ar: o menu ⋮ e o
  /// "Finalizar avaliação" ficam desabilitados até terminar — outra rota
  /// aberta por cima faria o fechamento do desatribuir fechar a tela errada.
  bool get _isBusy => _viewModel.isUnassigning || _viewModel.isDiscarding;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_showMessageWhenItArrives);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_showMessageWhenItArrives);
    _viewModel.dispose();
    super.dispose();
  }

  /// Mesmo padrão do detalhe da sessão: o aviso é passageiro, e a mensagem é
  /// limpa assim que é agendada.
  void _showMessageWhenItArrives() {
    final message = _viewModel.message;
    if (message == null) return;
    _viewModel.clearMessage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
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
            _buildHeader(context, isOffline),
            ConnectivityBanner(
              isOffline: isOffline,
              message: 'Sem conexão — as marcações continuam sendo salvas no aparelho.',
            ),
            Expanded(child: _buildBody()),
            if (!_viewModel.isLoading && _viewModel.hasCatalog && !_viewModel.isConfirmed)
              _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isOffline) {
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
              if (!_viewModel.isLoading &&
                  (_viewModel.canDiscard || _viewModel.canUnassign))
                _buildMenu(isOffline),
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

  /// Menu ⋮ (decisão de 01/10/2026 — não está no canvas): "Descartar
  /// avaliação", com a avaliação iniciada, e "Desatribuir participante", que
  /// precisa de rede — offline, aparece desabilitado e diz por quê. Com um
  /// desatribuir ou um descarte no ar, o menu não abre.
  Widget _buildMenu(bool isOffline) {
    return SizedBox.square(
      dimension: AppSpacing.touchTarget,
      child: PopupMenuButton<_MenuAction>(
        key: const Key('checklist-menu'),
        tooltip: 'Mais opções',
        enabled: !_isBusy,
        icon: const Icon(AppIcons.more, color: AppColors.text),
        onSelected: (action) => switch (action) {
          _MenuAction.discard => _confirmDiscard(),
          _MenuAction.unassign => _confirmUnassign(),
        },
        itemBuilder: (context) => [
          if (_viewModel.canDiscard)
            const PopupMenuItem(
              value: _MenuAction.discard,
              child: Text('Descartar avaliação'),
            ),
          if (_viewModel.canUnassign)
            PopupMenuItem(
              value: _MenuAction.unassign,
              enabled: !isOffline,
              child: isOffline
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Desatribuir participante'),
                        Text('Disponível quando houver conexão', style: AppTypography.meta),
                      ],
                    )
                  : const Text('Desatribuir participante'),
            ),
        ],
      ),
    );
  }

  /// Volta para "Pendente" ou, numa reavaliação, para "Necessita
  /// reavaliação" — a mesma regra do backend.
  Future<void> _confirmUnassign() async {
    final participant = _viewModel.participant;
    final name = participant?.name;
    final status = participant?.hasPreviousAssessment == true
        ? 'Necessita reavaliação'
        : 'Pendente';
    final discardNote =
        _viewModel.isStarted ? ' A avaliação iniciada será descartada.' : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(name == null ? 'Desatribuir o participante?' : 'Desatribuir $name?'),
        content: Text(
          '${name ?? 'O participante'} volta para "$status" e fica disponível '
          'para outro consultor.$discardNote',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desatribuir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final unassigned = await _viewModel.unassign();
    if (!unassigned || !mounted) return;
    // O SnackBar é do `ScaffoldMessenger` do app: continua na tela de baixo.
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Participante desatribuído.')));
    await Navigator.of(context).maybePop();
  }

  Future<void> _confirmDiscard() async {
    final name = _viewModel.participant?.name;
    // "de Ana Paula Ribeiro" ou, sem o nome no aparelho, "deste participante".
    final whose = name == null ? 'deste participante' : 'de $name';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar a avaliação?'),
        content: Text(
          'As marcações e a hora de início $whose serão apagadas. O '
          'participante continua com você.',
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
    if (confirmed == true && mounted) await _viewModel.discard();
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
        // Encolhe com reticências: com o menu ⋮ ao lado, "Iniciada em 28 set
        // 08:12" não cabe inteiro num celular estreito.
        Flexible(
          child: Text(
            _viewModel.startedText ?? '',
            style: AppTypography.meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(width: 1, height: 11, color: AppColors.borderStrong),
        const SizedBox(width: AppSpacing.sm),
        const Icon(AppIcons.syncDone, size: 14, color: AppColors.savedInk),
        const SizedBox(width: AppSpacing.xs),
        Text('salvo', style: AppTypography.savedLabel),
      ],
    );
  }

  /// A nota do participante: começa em 100% e cai a cada infração marcada.
  /// A barra acompanha a nota (decisão de 30/09/2026) e fica vermelha abaixo
  /// do corte de aprovação.
  Widget _buildProgress() {
    final score = _viewModel.overallScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(percentLabel(score), style: AppTypography.checklistProgressValue),
        const SizedBox(height: AppSpacing.xs + 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              _viewModel.isApproved ? AppColors.primary : AppColors.dangerInk,
            ),
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
        // Só leitura (decisão de 01/10/2026): a avaliação confirmada espera o
        // envio, e o que foi confirmado não muda mais.
        if (_viewModel.isConfirmed)
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
            child: InlineNotice(
              icon: AppIcons.finish,
              message: 'Avaliação confirmada — não pode mais ser alterada.',
            ),
          ),
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm + 2),
          blocks[i],
        ],
      ],
    );
  }

  /// Antes do "Iniciar avaliação" (decisão de 29/09/2026): o consultor pode ter
  /// aberto o participante sem querer — nada foi gravado, e voltar não deixa
  /// rastro. Segue o quadro "6a" do canvas (1.4.1): o aviso, o que será
  /// avaliado (só leitura, sem pontos — o app não tem pontos) e, no rodapé, o
  /// botão.
  Widget _buildNotStarted() {
    final sections = _viewModel.sections;
    final items = sections.fold<int>(0, (sum, s) => sum + s.infractions.length);

    return ListView(
      key: const Key('checklist-not-started'),
      children: [
        _buildNotStartedHero(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.sm + 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('O que será avaliado', style: AppTypography.sectionTitle),
              Text(_itemsLabel(items), style: AppTypography.categoryCount),
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [for (final category in sections) _buildPreviewCategory(category)],
          ),
        ),
      ],
    );
  }

  Widget _buildNotStartedHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
        AppSpacing.xxl + 4,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const Icon(AppIcons.timer, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm + 6),
          Text(
            'A avaliação ainda não começou.',
            style: AppTypography.notStartedTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A hora de início é registrada quando você tocar em "Iniciar avaliação".',
            style: AppTypography.notStartedBody,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Uma categoria da lista "O que será avaliado": o código, o nome e quantos
  /// itens tem. Só leitura — a lista abre depois do "Iniciar".
  Widget _buildPreviewCategory(ChecklistCategory category) {
    return Container(
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
          Text(_itemsLabel(category.infractions.length), style: AppTypography.categoryCount),
        ],
      ),
    );
  }

  String _itemsLabel(int count) => count == 1 ? '1 item' : '$count itens';

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
            Text(_itemsLabel(category.infractions.length), style: AppTypography.categoryCount),
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
                    onTap: _viewModel.isConfirmed
                        ? null
                        : () => _viewModel.toggleNote(infraction.id, infraction.notes[i].id),
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
              onPressed: _isBusy ? null : _openSummary,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_viewModel.isBlocked) ...[
                  InlineNotice(
                    icon: AppIcons.timer,
                    tone: NoticeTone.warning,
                    message: _blockedMessage(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppCtaButton(
                  label: 'Iniciar avaliação',
                  icon: AppIcons.startEvaluation,
                  size: AppCtaSize.large,
                  isLoading: _viewModel.isStarting,
                  onPressed: _viewModel.isBlocked ? null : _viewModel.start,
                ),
              ],
            ),
    );
  }

  /// Só uma avaliação por vez (decisão de 01/10/2026): o consultor precisa
  /// finalizar ou descartar a que está em andamento antes de iniciar outra.
  String _blockedMessage() {
    final name = _viewModel.blockingParticipantName;
    final who = name == null ? 'com outra avaliação em andamento' : 'avaliando $name';
    return 'Você já está $who. Finalize ou descarte essa avaliação para iniciar outra.';
  }

  /// "Finalizar avaliação" abre a conferência (tela 1.6), sem o diálogo das
  /// categorias sem marcação da Fase 4: a 1.6 mostra cada categoria com o %
  /// antes do "Confirmar" (decisão de 29/09/2026). Quem põe na fila é o
  /// "Confirmar" de lá; daqui, só se decide para onde ir: ao Resultado
  /// (confirmou), à categoria tocada ou de volta ao checklist.
  Future<void> _openSummary() async {
    final exit = await context.push<SummaryExit>(
      AppRoutes.participantSummary(widget.sessionId, widget.participantId),
    );
    if (!mounted) return;

    switch (exit) {
      case SummaryConfirmed():
        // Confirmada: o Resultado ("Avaliação concluída") toma o lugar do
        // checklist, como no canvas — o X e o "Próximo participante" de lá
        // voltam ao detalhe da sessão (decisão de 01/10/2026).
        context.pushReplacement(
          AppRoutes.participantResult(
            widget.sessionId,
            widget.participantId,
            justConfirmed: true,
          ),
        );
      case SummaryReviewCategory(:final categoryId):
        _openCategory(categoryId);
      case null:
        break;
    }
  }
}

/// O que o menu ⋮ do cabeçalho oferece.
enum _MenuAction { discard, unassign }

/// Um dos 3 botões B/PM/M (spec "4z"): raio 8, nunca pílula, para não se
/// confundir com os chips de status. Sem [onTap], é só leitura.
class _NoteButton extends StatelessWidget {
  const _NoteButton({required this.note, required this.selected, required this.onTap});

  final ChecklistNoteOption note;
  final bool selected;
  final VoidCallback? onTap;

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
