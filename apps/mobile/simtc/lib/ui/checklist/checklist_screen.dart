import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../router.dart';
import '../core/form_factor.dart';
import '../core/open_once.dart';
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
    this.fromResult = false,
  });

  final String sessionId;
  final String participantId;

  /// Aberto pelo "Reavaliar" do Resultado (decisão de 06/10/2026): o
  /// Resultado da avaliação anterior continua embaixo, e o voltar leva a ele.
  /// No "Confirmar", ele sai junto com o checklist, para o Resultado novo
  /// ficar direto sobre o detalhe da sessão.
  final bool fromResult;

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
    consultantName: context.read<AuthRepository>().currentUser!.name,
    assessmentRepository: context.read<AssessmentRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    catalogRepository: context.read<AssessmentCatalogRepository>(),
  )..init();

  /// Cabeçalho da categoria aberta — há no máximo uma, então uma chave basta.
  final GlobalKey _openHeaderKey = GlobalKey();

  /// O menu ⋮ muda de lugar no cabeçalho ao girar (linha única em paisagem,
  /// duas faixas em retrato): a chave leva o estado junto, e a escolha feita
  /// com o menu aberto durante o giro não se perde.
  final GlobalKey _menuKey = GlobalKey(debugLabel: 'menu-do-checklist');

  /// Coluna do "não iniciada" no tablet em paisagem (quadro "6b").
  static const double notStartedMaxWidth = 760;

  /// Largura do botão no fim dessa coluna.
  static const double notStartedCtaWidth = 420;

  /// Largura máxima da nota no cabeçalho do tablet em paisagem (quadro "4f").
  static const double headerProgressMaxWidth = 360;

  /// Largura máxima do nome no cabeçalho do tablet em paisagem: a nota fica
  /// com o resto.
  static const double headerNameMaxWidth = 320;

  /// Largura dos três botões B/PM/M ao lado da descrição, no tablet em
  /// paisagem (quadro "4f") e em retrato (quadro "4q").
  static const double notesWidthExpanded = 312;
  static const double notesWidthTablet = 264;

  /// Largura do número do item, no tablet.
  static const double numberWidthTablet = 18;

  /// Largura máxima da observação da nota, no tablet em paisagem.
  static const double commentMaxWidthExpanded = 620;

  /// Um desatribuir (que espera o backend) ou um descarte no ar: o menu ⋮ e o
  /// "Finalizar avaliação" ficam desabilitados até terminar — outra rota
  /// aberta por cima faria o fechamento do desatribuir fechar a tela errada.
  bool get _isBusy => _viewModel.isUnassigning || _viewModel.isDiscarding;

  /// O checklist largo do tablet (quadros "4f" e "4q"): o "Finalizar
  /// avaliação" no cabeçalho e os botões B/PM/M ao lado da descrição. Numa
  /// janela mais estreita que 600 (tela dividida), o botão volta ao rodapé e
  /// os botões B/PM/M voltam para baixo da descrição, como no celular.
  bool get _wideLayout =>
      context.isTablet &&
      MediaQuery.sizeOf(context).width >= AppBreakpoints.tabletShortestSide;

  bool get _finishInHeader =>
      _wideLayout && _showsProgress && !_viewModel.isConfirmed;

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
    final footer = _buildFooter();

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
            if (footer != null) footer,
          ],
        ),
      ),
    );
  }

  /// No tablet (quadros "6b" e "6c"), o cabeçalho tem 12 embaixo e recua 24
  /// à direita em paisagem e 20 em retrato; o nome tem 18. Com a avaliação
  /// iniciada, o "Finalizar avaliação" entra no cabeçalho: em paisagem, numa
  /// linha com o nome e a nota (quadro "4f"); em retrato, ao lado do nome, com
  /// a nota numa segunda faixa (quadro "4q").
  Widget _buildHeader(BuildContext context, bool isOffline) {
    final tablet = context.isTablet;
    final expanded = context.isExpandedLayout;
    final double right = !tablet
        ? AppSpacing.sm
        : expanded
            ? AppSpacing.xxl
            : AppSpacing.xl;
    final showsProgress = _showsProgress;

    if (expanded && _finishInHeader) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, right, AppSpacing.md),
        child: Row(
          children: [
            _buildBackButton(context),
            const SizedBox(width: AppSpacing.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: headerNameMaxWidth),
              child: _buildNameAndTimer(),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: headerProgressMaxWidth),
                  child: _buildProgress(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            _buildHeaderFinish(),
            if (!_viewModel.isLoading &&
                (_viewModel.canDiscard || _viewModel.canUnassign)) ...[
              const SizedBox(width: AppSpacing.sm),
              _buildMenu(isOffline),
            ],
          ],
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        right,
        tablet ? AppSpacing.md : AppSpacing.sm + 2,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildBackButton(context),
              SizedBox(width: tablet ? AppSpacing.md : AppSpacing.xs),
              Expanded(child: _buildNameAndTimer()),
              if (_finishInHeader) ...[
                const SizedBox(width: AppSpacing.md),
                _buildHeaderFinish(),
              ],
              if (!_viewModel.isLoading &&
                  (_viewModel.canDiscard || _viewModel.canUnassign)) ...[
                if (_finishInHeader) const SizedBox(width: AppSpacing.sm),
                _buildMenu(isOffline),
              ],
            ],
          ),
          if (showsProgress)
            Padding(
              padding: tablet
                  ? const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0)
                  : const EdgeInsets.fromLTRB(
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

  bool get _showsProgress =>
      !_viewModel.isLoading && _viewModel.hasCatalog && _viewModel.isStarted;

  Widget _buildBackButton(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpacing.touchTarget,
      child: IconButton(
        tooltip: 'Voltar',
        icon: const Icon(AppIcons.back, size: 30, color: AppColors.text),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Widget _buildNameAndTimer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _viewModel.participant?.name ?? '',
          style: context.isTablet
              ? AppTypography.appBarTitleTablet
              : AppTypography.checklistParticipantName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs - 1),
        _buildTimerRow(),
      ],
    );
  }

  /// O "Finalizar avaliação" do cabeçalho do tablet: as mesmas regras do
  /// botão do rodapé do celular.
  Widget _buildHeaderFinish() {
    return AppCtaButton(
      label: 'Finalizar avaliação',
      icon: AppIcons.finish,
      size: AppCtaSize.header,
      fullWidth: false,
      onPressed: _isBusy || _viewModel.isReleased ? null : _openSummary,
    );
  }

  /// Menu ⋮ (decisão de 01/10/2026 — não está no canvas): "Descartar
  /// avaliação", com a avaliação iniciada, e "Desatribuir participante", que
  /// precisa de rede — offline, aparece desabilitado e diz por quê. Com um
  /// desatribuir ou um descarte no ar, o menu não abre.
  Widget _buildMenu(bool isOffline) {
    // Com o desatribuir esperando o backend (de 15 a 35 s com a rede lenta),
    // o ⋮ vira o indicador de carregamento pequeno (Fase 8C).
    if (_viewModel.isUnassigning) {
      return KeyedSubtree(
        key: _menuKey,
        child: Semantics(
          label: 'Desatribuindo…',
          child: const SizedBox.square(
            key: Key('checklist-desatribuindo'),
            dimension: AppSpacing.touchTarget,
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.text3),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return KeyedSubtree(
      key: _menuKey,
      child: SizedBox.square(
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
      ),
    );
  }

  /// Volta para "Pendente" ou, numa reavaliação, para "Não recomendado" —
  /// a mesma regra do backend.
  Future<void> _confirmUnassign() async {
    final participant = _viewModel.participant;
    final name = participant?.name;
    final status = participant?.hasPreviousAssessment == true
        ? 'Não recomendado'
        : 'Pendente';
    final discardNote = _viewModel.isStarted || _viewModel.isResumable
        ? ' A avaliação iniciada será descartada.'
        : '';
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
    // A avaliação parada pode ser de quem já não está com o consultor.
    final stays =
        _viewModel.isWithMe ? ' O participante continua com você.' : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar a avaliação?'),
        content: Text(
          'As marcações e a hora de início $whose serão apagadas.$stays',
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
          // A avaliação parada (Fase 6B) já tem hora de início.
          Flexible(
            child: Text(
              _viewModel.isResumable
                  ? _viewModel.startedText ?? ''
                  : 'não iniciada',
              style: AppTypography.meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
        ..._buildSavedState(),
      ],
    );
  }

  /// "salvo", ou "Não salvo" em vermelho depois de uma nota que não gravou
  /// (Fase 8C).
  List<Widget> _buildSavedState() {
    if (_viewModel.saveFailed) {
      return [
        const Icon(AppIcons.notSaved, size: 14, color: AppColors.dangerInk),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Não salvo',
          style: AppTypography.savedLabel.copyWith(color: AppColors.dangerInk),
        ),
      ];
    }
    return [
      const Icon(AppIcons.syncDone, size: 14, color: AppColors.savedInk),
      const SizedBox(width: AppSpacing.xs),
      Text('salvo', style: AppTypography.savedLabel),
    ];
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

    if (_viewModel.loadFailed) {
      return Padding(
        key: const Key('checklist-load-failed'),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const InlineNotice(
              icon: AppIcons.notSaved,
              tone: NoticeTone.danger,
              message: 'Não foi possível abrir a avaliação neste aparelho.',
            ),
            const SizedBox(height: AppSpacing.md),
            AppSecondaryButton(
              label: 'Tentar novamente',
              icon: AppIcons.retry,
              onPressed: _viewModel.retryLoad,
            ),
          ],
        ),
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

    // No tablet (quadros "4f" e "4q"), os blocos começam no topo e ficam
    // colados, e os avisos vão para o topo da lista, com o recuo de 24.
    final tablet = context.isTablet;
    final double inset = tablet ? AppSpacing.xxl : AppSpacing.xl;

    return ListView(
      padding: EdgeInsets.only(top: tablet ? 0 : AppSpacing.md),
      children: [
        // Só leitura (decisão de 01/10/2026): a avaliação confirmada espera o
        // envio, e o que foi confirmado não muda mais.
        if (_viewModel.isConfirmed)
          Padding(
            padding: tablet
                ? EdgeInsets.fromLTRB(inset, AppSpacing.md, inset, AppSpacing.md)
                : EdgeInsets.fromLTRB(inset, 0, inset, AppSpacing.md),
            child: const InlineNotice(
              icon: AppIcons.finish,
              message: 'Avaliação confirmada — não pode mais ser alterada.',
            ),
          ),
        // No celular, o aviso fica no rodapé, acima do botão.
        if (_wideLayout && _viewModel.isReleased)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, AppSpacing.md, inset, AppSpacing.md),
            child: _buildReleasedNotice(),
          ),
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0 && !tablet) const SizedBox(height: AppSpacing.sm + 2),
          blocks[i],
        ],
      ],
    );
  }

  /// O participante saiu das mãos do consultor com o checklist aberto: o
  /// servidor recusaria o envio (decisão de 09/10/2026). As marcações ficam.
  Widget _buildReleasedNotice() {
    return const InlineNotice(
      icon: AppIcons.lockedByOther,
      tone: NoticeTone.warning,
      message: 'Este participante não está mais com você. '
          'Atribua de novo para continuar.',
    );
  }

  /// Recuo das linhas e cabeçalhos de categoria: 20 no celular, 24 no tablet.
  EdgeInsets get _categoryPadding => context.isTablet
      ? const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xl)
      : const EdgeInsets.all(AppSpacing.xl);

  /// Vão entre as partes da linha de categoria: 10 no celular, 12 no tablet.
  double get _categoryGap => context.isTablet ? AppSpacing.md : AppSpacing.sm + 2;

  TextStyle get _categoryNameStyle =>
      context.isTablet ? AppTypography.categoryNameTablet : AppTypography.categoryName;

  /// Antes do "Iniciar avaliação" (decisão de 29/09/2026): o consultor pode ter
  /// aberto o participante sem querer — nada foi gravado, e voltar não deixa
  /// rastro. Segue o quadro "6a" do canvas (1.4.1): o aviso, o que será
  /// avaliado (só leitura, sem pontos — o app não tem pontos) e, no rodapé, o
  /// botão.
  ///
  /// No tablet em paisagem (quadro "6b"), tudo numa coluna de até 760,
  /// centrada, com o botão no fim dela; em retrato (quadro "6c"), recuo de 32
  /// e o botão no rodapé.
  Widget _buildNotStarted() {
    final sections = _viewModel.sections;
    final items = sections.fold<int>(0, (sum, s) => sum + s.infractions.length);
    final tablet = context.isTablet;
    final expanded = context.isExpandedLayout;
    final double inset = expanded
        ? 0
        : tablet
            ? AppSpacing.xxxl
            : AppSpacing.xl;

    final children = [
      _buildNotStartedHero(),
      Padding(
        padding: EdgeInsets.fromLTRB(
          inset,
          tablet && !expanded ? AppSpacing.xl : AppSpacing.lg,
          inset,
          AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            // Encolhe com reticências: num celular estreito com a fonte
            // ampliada, o título e a contagem não cabem inteiros na linha.
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'O que será avaliado',
                  style: tablet
                      ? AppTypography.sectionTitleTablet
                      : AppTypography.sectionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
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
          children: [
            for (final category in sections) _buildPreviewCategory(category, inset),
          ],
        ),
      ),
    ];

    if (!expanded) {
      return ListView(key: const Key('checklist-not-started'), children: children);
    }

    return ListView(
      key: const Key('checklist-not-started'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.huge,
        AppSpacing.sm,
        AppSpacing.huge,
        AppSpacing.xxxl,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            key: const Key('checklist-not-started-column'),
            constraints: const BoxConstraints(maxWidth: notStartedMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...children,
                const SizedBox(height: AppSpacing.xxl),
                _buildStartActions(ctaWidth: notStartedCtaWidth),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Com uma avaliação parada (decisão de 09/10/2026), o bloco diz quando
  /// ela começou, e o botão do rodapé vira "Continuar avaliação".
  Widget _buildNotStartedHero() {
    final startedAt = _viewModel.resumableStartedAt;
    final tablet = context.isTablet;
    final expanded = context.isExpandedLayout;

    // Quadros "6a" (celular), "6b" (paisagem) e "6c" (retrato).
    final EdgeInsets padding;
    final double iconSize;
    final TextStyle titleStyle;
    final TextStyle bodyStyle;
    if (expanded) {
      padding = const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl + 4,
        AppSpacing.xxl,
        AppSpacing.xxl,
      );
      iconSize = 44;
      titleStyle = AppTypography.notStartedTitleExpanded;
      bodyStyle = AppTypography.notStartedBodyExpanded;
    } else if (tablet) {
      padding = const EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        AppSpacing.huge,
        AppSpacing.xxxl,
        AppSpacing.xxxl + AppSpacing.sm,
      );
      iconSize = 48;
      titleStyle = AppTypography.notStartedTitleTablet;
      bodyStyle = AppTypography.notStartedBodyTablet;
    } else {
      padding = const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
        AppSpacing.xxl + 4,
      );
      iconSize = 40;
      titleStyle = AppTypography.notStartedTitle;
      bodyStyle = AppTypography.notStartedBody;
    }

    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Icon(AppIcons.timer, size: iconSize, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm + 6),
          Text(
            startedAt == null
                ? 'A avaliação ainda não começou.'
                : 'Você começou esta avaliação em $startedAt.',
            style: titleStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            startedAt == null
                ? 'A hora de início é registrada quando você tocar em '
                    '"Iniciar avaliação".'
                : 'As respostas voltam ao continuar.',
            style: bodyStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Uma categoria da lista "O que será avaliado": o código, o nome e quantos
  /// itens tem. Só leitura — a lista abre depois do "Iniciar".
  Widget _buildPreviewCategory(ChecklistCategory category, double inset) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: inset, vertical: AppSpacing.xl),
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
              style: context.isTablet
                  ? AppTypography.categoryNameTablet
                  : AppTypography.categoryName,
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
    final gap = _categoryGap;

    return InkWell(
      key: ValueKey('category-${category.id}'),
      onTap: () => _openCategory(category.id),
      child: Container(
        padding: _categoryPadding,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
        ),
        child: Row(
          children: [
            CategoryCodeChip(code: category.code),
            SizedBox(width: gap),
            Expanded(
              child: Text(
                category.name,
                style: _categoryNameStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: gap),
            Text(_itemsLabel(category.infractions.length), style: AppTypography.categoryCount),
            SizedBox(width: gap),
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
    final gap = _categoryGap;

    // O fundo é do `Material`, embaixo do `InkWell`, para a ondulação do
    // toque aparecer (Fase 8C).
    return Material(
      color: AppColors.categoryExpandedBg,
      child: InkWell(
        key: _openHeaderKey,
        onTap: () => _viewModel.toggleCategory(category.id),
        child: Container(
          padding: _categoryPadding,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.categoryExpandedBorder)),
          ),
          child: Row(
            children: [
              CategoryCodeChip(
                code: category.code,
                background: AppColors.primary,
                ink: AppColors.surface,
              ),
              SizedBox(width: gap),
              Expanded(
                child: Text(
                  category.name,
                  style: _categoryNameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: gap),
              ScoreBadge(score: category.score),
              SizedBox(width: gap),
              const Icon(AppIcons.expandLess, size: 22, color: AppColors.text3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfractionRow(ChecklistInfraction infraction) {
    if (_wideLayout) return _buildWideInfractionRow(infraction);

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
          _buildNoteButtons(infraction),
          if (comment != null) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            _NoteComment(comment),
          ],
        ],
      ),
    );
  }

  /// A linha de infração no tablet (quadros "4f" e "4q", spec "4z"): o
  /// número, a descrição (com a observação embaixo) e os botões B/PM/M à
  /// direita, em 312 de largura em paisagem e 264 em retrato.
  Widget _buildWideInfractionRow(ChecklistInfraction infraction) {
    final comment = infraction.selectedComment;
    final expanded = context.isExpandedLayout;
    final double gap = expanded ? AppSpacing.xxl : AppSpacing.lg;

    return Container(
      key: ValueKey('infraction-${infraction.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.md + 3,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: numberWidthTablet,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text('${infraction.order}', style: AppTypography.infractionNumber),
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(infraction.description, style: AppTypography.infractionDescription),
                if (comment != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: expanded ? commentMaxWidthExpanded : double.infinity,
                    ),
                    child: _NoteComment(comment),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: gap),
          SizedBox(
            width: expanded ? notesWidthExpanded : notesWidthTablet,
            child: _buildNoteButtons(infraction),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteButtons(ChecklistInfraction infraction) {
    return Row(
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
    );
  }

  /// O rodapé do checklist. No tablet em paisagem, antes do "Iniciar", o
  /// botão fica no fim da coluna (quadro "6b") e não há rodapé; em retrato,
  /// o rodapé tem 16 em cima e embaixo, 32 dos lados e o fundo cinza-claro
  /// (quadro "6c").
  Widget? _buildFooter() {
    if (_viewModel.isLoading || !_viewModel.hasCatalog || _viewModel.isConfirmed) {
      return null;
    }

    final tablet = context.isTablet;
    if (!_viewModel.isStarted && context.isExpandedLayout) return null;
    // No tablet, o "Finalizar avaliação" fica no cabeçalho.
    if (_viewModel.isStarted && _wideLayout) return null;
    final tabletStart = tablet && !_viewModel.isStarted;

    return Container(
      decoration: BoxDecoration(
        color: tabletStart ? AppColors.background : AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: tabletStart
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxxl,
              vertical: AppSpacing.lg,
            )
          : const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
      child: _viewModel.isStarted
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // O participante saiu das mãos do consultor com o checklist
                // aberto: o servidor recusaria o envio (decisão de
                // 09/10/2026). As marcações ficam.
                if (_viewModel.isReleased) ...[
                  _buildReleasedNotice(),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppCtaButton(
                  label: 'Finalizar avaliação',
                  icon: AppIcons.finish,
                  size: AppCtaSize.large,
                  onPressed: _isBusy || _viewModel.isReleased
                      ? null
                      : _openSummary,
                ),
              ],
            )
          : _buildStartActions(),
    );
  }

  /// O aviso de outra avaliação em andamento e o "Iniciar avaliação". Com
  /// [ctaWidth], o botão tem essa largura e fica centrado (quadro "6b").
  Widget _buildStartActions({double? ctaWidth}) {
    final button = AppCtaButton(
      label: _viewModel.isResumable ? 'Continuar avaliação' : 'Iniciar avaliação',
      icon: AppIcons.startEvaluation,
      size: context.isTablet ? AppCtaSize.tabletLarge : AppCtaSize.large,
      isLoading: _viewModel.isStarting,
      onPressed: _viewModel.isBlocked ? null : _viewModel.start,
    );

    return Column(
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
        if (ctaWidth == null)
          button
        else
          Center(child: SizedBox(width: ctaWidth, child: button)),
      ],
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
    if (!context.claimOpen()) return;
    final exit = await context.push<SummaryExit>(
      AppRoutes.participantSummary(widget.sessionId, widget.participantId),
    );
    if (!mounted) return;

    switch (exit) {
      case SummaryConfirmed():
        // Confirmada: o Resultado ("Avaliação concluída") toma o lugar do
        // checklist, como no canvas — o X e o "Próximo participante" de lá
        // voltam ao detalhe da sessão (decisão de 01/10/2026).
        final router = GoRouter.of(context);
        // Numa reavaliação aberta pelo Resultado, o da avaliação anterior
        // ainda está embaixo: o checklist sai, e o Resultado novo entra no
        // lugar do antigo.
        if (widget.fromResult) router.pop();
        router.pushReplacement(
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
    // O fundo é do `Material`, embaixo do `InkWell`, para a ondulação do
    // toque aparecer. O leitor de tela diz qual está marcado (Fase 8C).
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            height: AppSpacing.controlHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: colors.border, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(note.noteType, style: AppTypography.noteButton.copyWith(color: colors.ink)),
          ),
        ),
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
