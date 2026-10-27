import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/training_session.dart';
import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../router.dart';
import '../core/date_labels.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_nav_bar.dart';
import '../core/widgets/app_search_field.dart';
import '../core/widgets/company_logo.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/filter_chip_bar.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/session_card.dart';
import '../core/widgets/skeleton.dart';
import '../core/widgets/status_chip.dart';
import '../core/widgets/sync_status_indicator.dart';
import 'session_filter.dart';
import 'session_status_style.dart';
import 'sessions_list_viewmodel.dart';

/// Tela 1.3 — a Home do app.
///
/// No tablet em retrato é a mesma lista do celular, alargada, com a navbar
/// em pílula do tablet. Em paisagem é o painel da esquerda ([embedded]), ao
/// lado do detalhe: sem navbar própria (a lateral é da moldura), com o
/// cabeçalho do quadro "4c" e o card da sessão aberta destacado.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({
    super.key,
    this.embedded = false,
    this.selectedSessionId,
    this.onOpenSession,
    this.sessionOpen = false,
  });

  /// Painel da esquerda do tablet em paisagem.
  final bool embedded;

  /// A sessão aberta ao lado da lista, que o card destaca.
  final String? selectedSessionId;

  /// O toque no card. Sem ele, o detalhe é empilhado por cima da lista.
  final ValueChanged<String>? onOpenSession;

  /// No tablet, há uma sessão aberta (ao lado, ou por cima em retrato): o
  /// voltar é do lado a lado, que fecha a sessão, e a busca da lista fica.
  final bool sessionOpen;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late final SessionsListViewModel _viewModel = SessionsListViewModel(
    repository: context.read<SessionRepository>(),
    catalog: context.read<AssessmentCatalogRepository>(),
    connectivity: context.read<ConnectivityService>(),
  )..init();

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  final Map<SessionFilter, GlobalKey> _sectionKeys = {
    for (final filter in SessionFilter.values) filter: GlobalKey(),
  };

  /// Suspende a leitura do scroll manual enquanto alguma animação de toque de
  /// chip está rodando — sem isso, o chip picaria entre seções intermediárias
  /// até o scroll assentar no destino. É contador, não booleano: um segundo
  /// toque antes do primeiro `Scrollable.ensureVisible` terminar cancela a
  /// activity anterior, o que resolve a `Future` dela imediatamente
  /// (`DrivenScrollActivity.dispose()` chama `_completer.complete()` sem
  /// condição). Com um booleano, essa resolução antecipada zeraria a flag com
  /// a animação do segundo toque ainda em voo, reabrindo o listener no meio
  /// do caminho. O contador só chega a 0 quando a última chamada em voo
  /// também terminar seu `finally`.
  int _programmaticScrollCount = 0;

  /// ~130px por card (`SessionCard`) × até 20 na seção "Hoje" (bloco
  /// principal + "Outras", que acumula se o consultor ficar tempo sem abrir
  /// o app) + headers + margem para a seção seguinte. Ver `session_card.dart`
  /// para a origem do número por card.
  static const double _sectionsCacheExtent = 5000.0;

  /// Cada toque em chip tem sua própria geração. Um segundo toque, disparado
  /// enquanto o primeiro ainda está suspenso num `await` (fallback de seção
  /// desmontada, ou a animação final do `ensureVisible`), incrementa este
  /// contador — quando o primeiro retoma, `gen != _tapGeneration` avisa que
  /// ele não é mais a chamada mais recente e ele deve parar sem mexer em
  /// `_scrollController` nem em `_viewModel`. Sem isso, o primeiro toque
  /// retomaria depois do `await` e continuaria pro alvo antigo, cancelando a
  /// animação do segundo toque no meio do caminho (ver `_onChipTap`).
  int _tapGeneration = 0;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_showErrorWhenItArrives);
    _scrollController.addListener(_updateActiveChipFromScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateActiveChipFromScroll);
    _scrollController.dispose();
    _viewModel.removeListener(_showErrorWhenItArrives);
    _viewModel.dispose();
    super.dispose();
  }

  /// A falha de atualização é um aviso passageiro, não um estado da tela: a
  /// lista cacheada continua válida e visível. Por isso SnackBar, e por isso a
  /// mensagem é limpa assim que é agendada — limpar antes de agendar também
  /// evita reentrância, já que `clearError()` notifica de novo.
  void _showErrorWhenItArrives() {
    final message = _viewModel.errorMessage;
    if (message == null) return;
    _viewModel.clearError();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildScaffold(context, _viewModel),
    );
  }

  /// Toque num chip: marca a seção correspondente e rola até ela.
  Future<void> _onChipTap(SessionFilter filter) async {
    final gen = ++_tapGeneration;
    final previousFilter = _viewModel.filter;
    _viewModel.setFilter(filter);

    var target = _sectionKeys[filter]?.currentContext;

    // O contador protege a operação inteira, não só o `ensureVisible` final:
    // o `jumpTo` do fallback logo abaixo também mexe em `ScrollPosition`, e
    // `ScrollPosition.forcePixels` notifica os listeners de forma síncrona
    // (`scroll_position.dart`), sem esperar nenhum layout. Se o contador só
    // fosse incrementado depois do fallback, esse `jumpTo` reabriria a
    // mesma dessincronia que o Achado B corrigiu — `_updateActiveChipFromScroll`
    // rodaria com geometria desatualizada e destacaria o chip errado, mesmo
    // o `ensureVisible` seguinte rolando pro lugar certo.
    _programmaticScrollCount++;
    try {
      if (target == null && _scrollController.hasClients) {
        // A seção não está montada — saiu da faixa que o ListView mantém
        // construída mesmo com o cacheExtent recalibrado. "Hoje" é sempre a
        // primeira seção, "Concluídas" a última; saltar pro extremo
        // correspondente e esperar um frame geralmente é suficiente para o
        // Flutter montar aquela área antes de tentar de novo. "Esta semana",
        // no meio, também usa o salto pro fim — não tem o mesmo atalho
        // determinístico de extremo próprio, então o efeito visível nesse
        // caso raro é um salto até o fim da lista seguido da animação de
        // `ensureVisible` subindo até a seção, em vez de uma rolagem direta.
        final position = _scrollController.position;
        final originalOffset = position.pixels;
        final extent = filter == SessionFilter.hoje
            ? position.minScrollExtent
            : position.maxScrollExtent;
        _scrollController.jumpTo(extent);
        await WidgetsBinding.instance.endOfFrame;

        // Um segundo toque pode ter começado (e até terminado) enquanto este
        // estava suspenso aqui — se essa geração não é mais a mais recente,
        // ou o State já foi descartado, parar sem tocar em
        // `_scrollController`/`_viewModel` de novo: eles podem não refletir
        // mais esta chamada, ou nem existir.
        if (gen != _tapGeneration || !mounted) return;

        target = _sectionKeys[filter]?.currentContext;
        if (target == null || !target.mounted) {
          // O fallback não achou a seção nem depois do salto — volta pra
          // onde estava e pro filtro que estava ativo antes deste toque, em
          // vez de deixar o consultor largado num extremo da lista com o
          // chip marcando uma seção que não está na tela.
          _scrollController.jumpTo(originalOffset);
          _viewModel.setFilter(previousFilter);
          return;
        }
      }

      if (target == null || !target.mounted) return;

      await Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      if (gen != _tapGeneration || !mounted) return;
    } finally {
      _programmaticScrollCount--;
    }
  }

  /// Enquanto o dedo rola a lista (sem ter tocado em nenhum chip), decide
  /// qual seção está mais visível — a última cujo topo já passou do topo da
  /// área rolável — e destaca o chip correspondente. Nunca dispara um novo
  /// scroll: só o toque explícito faz isso, senão vira loop.
  void _updateActiveChipFromScroll() {
    // Com a busca aberta, os chips saem de cena: não há o que destacar.
    if (_viewModel.isSearching) return;
    if (_programmaticScrollCount > 0) return;
    if (!_scrollController.hasClients) return;

    final listBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (listBox == null || !listBox.attached) return;
    final activationOffset = listBox.localToGlobal(Offset.zero).dy;

    RenderBox? sectionBox(SessionFilter filter) =>
        _sectionKeys[filter]?.currentContext?.findRenderObject() as RenderBox?;

    SessionFilter? active;
    for (final filter in SessionFilter.values) {
      final box = sectionBox(filter);
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= activationOffset) {
        active = filter;
      }
    }

    // No fim absoluto do scroll, a seção na tela é sempre a última
    // ("Concluídas" — as três existem sempre, nesta ordem). A geometria não
    // serve aqui: se ela for curta, o cabeçalho nunca cruza a linha de
    // ativação (não há conteúdo abaixo para empurrá-lo); se for longa (dezenas
    // de concluídas, agora com um subtítulo por dia), o cabeçalho sai do
    // cacheExtent e nem está montado. Nos dois casos o chip ficaria preso numa
    // seção anterior.
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 1) {
      active = SessionFilter.values.last;
    }

    // Quando nenhuma seção cruzou a linha (topo absoluto da lista, ou um
    // fling rápido que passa por este listener antes do layout assentar), o
    // filtro ativo cai para "Hoje" em vez de ficar preso na última seção que
    // alguma vez foi destacada.
    _viewModel.setFilter(active ?? SessionFilter.hoje);
  }

  Widget _buildScaffold(BuildContext context, SessionsListViewModel viewModel) {
    final isOffline = context.watch<ConnectivityService>().isOffline;
    // Tablet em retrato: a pílula do tablet, posta pela moldura. Em paisagem
    // quem põe a navbar é a moldura de fora, que envolve os dois painéis.
    final tabletPortrait = context.isTablet && !widget.embedded;
    final content = Column(
      children: [
        _buildHeader(context),
        ConnectivityBanner(
          isOffline: isOffline,
          message: offlineDataMessage(viewModel.lastSyncedAt),
        ),
        if (!viewModel.isSearching) _buildFilters(viewModel),
        Expanded(child: _buildBody(viewModel)),
      ],
    );

    // O voltar do Android fecha a busca antes de fechar o app. Com uma
    // sessão aberta no tablet, quem cuida do voltar é o lado a lado
    // (`SessionsSplitView`), que fecha a sessão — e a busca fica.
    return PopScope(
      canPop: widget.sessionOpen || !viewModel.isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !widget.sessionOpen && viewModel.isSearching) {
          viewModel.closeSearch();
        }
      },
      child: _buildPage(content, tabletPortrait: tabletPortrait),
    );
  }

  Widget _buildPage(Widget content, {required bool tabletPortrait}) {
    return TabSnackBarArea(
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          bottom: tabletPortrait,
          child: tabletPortrait
              ? TabletNavFrame(current: AppTab.sessions, child: content)
              : content,
        ),
        bottomNavigationBar: context.isTablet
            ? null
            : const AppNavBar(current: AppTab.sessions),
      ),
    );
  }

  /// Com a busca aberta (Fase 8B), o campo toma o lugar da saudação e do
  /// título; a linha do logo e do indicador de envio continua em cima.
  Widget _buildHeader(BuildContext context) {
    final embedded = widget.embedded;

    // Painel de paisagem (quadro "4c"): 12/12/12/20 de recuo, saudação de 13
    // e título de 22.
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: embedded
          ? const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            )
          : const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm + 2,
              AppSpacing.md,
              AppSpacing.sm + 2,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/logo-simtc.png',
                height: AppSpacing.huge + AppSpacing.md,
                semanticLabel: 'SIM Treinamentos',
              ),
              const Spacer(),
              // A lupa, a 4 do indicador (quadro "2c"); some enquanto o campo
              // está aberto, que já tem o X.
              if (!_viewModel.isSearching) ...[
                AppSearchButton(onPressed: _viewModel.openSearch),
                const SizedBox(width: AppSpacing.xs),
              ],
              SyncStatusIndicator(onTap: () => context.go(AppRoutes.sync)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          if (_viewModel.isSearching)
            AppSearchField(
              hintText: 'Buscar pela empresa',
              initialText: _viewModel.searchQuery,
              onChanged: _viewModel.setSearchQuery,
              onClose: _viewModel.closeSearch,
            )
          else
            ..._buildTitle(context),
        ],
      ),
    );
  }

  List<Widget> _buildTitle(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;
    final title = user?.isAdmin == true ? 'Sessões' : 'Minhas sessões';
    final embedded = widget.embedded;

    return [
      Text(
        _greeting(user?.name),
        style:
            embedded ? AppTypography.screenSubtitle : AppTypography.homeGreeting,
      ),
      const SizedBox(height: AppSpacing.xxs),
      // O key desambigua o título do rótulo 'Sessões' da navbar, que tem o
      // mesmo texto quando o usuário é ADMIN.
      Text(
        title,
        key: const Key('sessions-title'),
        style: embedded ? AppTypography.screenTitle : AppTypography.homeTitle,
      ),
    ];
  }

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final periodo = hour < 12
        ? 'Bom dia'
        : hour < 18
            ? 'Boa tarde'
            : 'Boa noite';
    final firstName = (name ?? '').trim().split(' ').first;
    return firstName.isEmpty ? periodo : '$periodo, $firstName';
  }

  Widget _buildFilters(SessionsListViewModel viewModel) {
    final counts = viewModel.counts;

    return Container(
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: FilterChipBar(
        items: [
          for (final filter in SessionFilter.values)
            FilterChipData(label: filter.label, count: counts[filter]),
        ],
        selectedIndex: SessionFilter.values.indexOf(viewModel.filter),
        onSelect: (index) => _onChipTap(SessionFilter.values[index]),
      ),
    );
  }

  Widget _buildBody(SessionsListViewModel viewModel) {
    if (viewModel.isLoading) return _buildSkeleton();

    // Na busca, a seção sem resultado some com o título; sem nenhum, uma
    // frase diz que não achou (decisões de 24/10/2026).
    final sections = viewModel.isFiltering
        ? viewModel.sections.where((s) => !s.isEmpty).toList(growable: false)
        : viewModel.sections;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: viewModel.refresh,
      child: ListView(
        key: _listKey,
        controller: _scrollController,
        // Explícito por segurança: um `ListView` sem `controller` já é
        // "primary" e ganha essa física por padrão, mas deixar implícito
        // depende desse detalhe do framework.
        physics: const AlwaysScrollableScrollPhysics(),
        // O `Scrollable.ensureVisible` do toque no chip só encontra a seção
        // se ela já estiver montada na árvore — a virtualização do `ListView`
        // descarta o que sai do `cacheExtent` padrão (250px lógicos), bem
        // menos do que um scroll comum leva o consultor. `visibleCount` de
        // cada bloco (Task 1/3) já limita quantos itens existem na lista
        // lógica; isto só dá mais margem para o que já está nela continuar
        // pré-montado fora da viewport. Quando mesmo assim a seção sair dessa
        // faixa, `_onChipTap` tem um fallback determinístico (ver lá).
        cacheExtent: _sectionsCacheExtent,
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.huge * 2,
        ),
        children: [
          if (viewModel.isFiltering && sections.isEmpty)
            _buildNoResults(viewModel.searchQuery.trim()),
          for (final section in sections) ..._buildSection(viewModel, section),
        ],
      ),
    );
  }

  /// As três seções sempre aparecem, sempre nesta ordem — os chips só rolam
  /// até elas, nunca escondem nenhuma. Cada bloco dentro da seção pagina de
  /// forma independente dos demais.
  List<Widget> _buildSection(
    SessionsListViewModel viewModel,
    SessionSection section,
  ) {
    return [
      Padding(
        key: _sectionKeys[section.filter],
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg - 1,
        ),
        child: Text(section.title, style: AppTypography.sectionTitle),
      ),
      if (section.isEmpty)
        _buildSectionEmpty(section.filter)
      else
        for (final block in section.blocks) ..._buildBlock(viewModel, block),
    ];
  }

  List<Widget> _buildBlock(SessionsListViewModel viewModel, SessionBlock block) {
    // O bloco principal de "Hoje" pode ficar vazio mesmo com a seção não
    // vazia (há sessões em "Outras") — os outros blocos com `totalCount == 0`
    // nunca chegam aqui, porque `_buildSection` já mostra a seção inteira
    // vazia (`_buildSectionEmpty`) quando todo bloco dela está vazio. Aqui é
    // só o primeiro bloco que está vazio; "Outras" continua aparecendo logo
    // depois, sem se esconder.
    if (block.id == SessionBlockId.hojePrincipal && block.totalCount == 0) {
      return [_buildSectionEmpty(SessionFilter.hoje)];
    }

    return [
      if (block.title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: Text(
            block.title!,
            style: AppTypography.blockTitle,
          ),
        ),
      for (final dayGroup in block.dayGroups) ..._buildDayGroup(dayGroup),
      if (block.hasMore) _buildRevealMoreButton(viewModel, block),
    ];
  }

  List<Widget> _buildDayGroup(SessionDayGroup dayGroup) {
    return [
      if (dayGroup.title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm + 2,
            AppSpacing.xl,
            AppSpacing.xs,
          ),
          child: Text(dayGroup.title!, style: AppTypography.meta),
        ),
      for (final session in dayGroup.sessions) _buildCard(session),
    ];
  }

  Widget _buildRevealMoreButton(
    SessionsListViewModel viewModel,
    SessionBlock block,
  ) {
    return Padding(
      key: ValueKey('ver-mais-${block.id.name}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Center(
        child: TextButton(
          onPressed: () => viewModel.revealMore(block.id),
          child: Text('Ver mais', style: AppTypography.link),
        ),
      ),
    );
  }

  Widget _buildNoResults(String query) {
    return Padding(
      key: const Key('sessions-no-results'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: InlineNotice(
        icon: AppIcons.search,
        message: 'Nenhuma sessão encontrada para “$query”.',
      ),
    );
  }

  /// A seção nunca some, mesmo vazia — é o que garante que o chip sempre tem
  /// um lugar real pra rolar até.
  Widget _buildSectionEmpty(SessionFilter filter) {
    final message = switch (filter) {
      SessionFilter.hoje => 'Nenhuma sessão para hoje.',
      SessionFilter.proximos7 => 'Nada agendado para os próximos 7 dias.',
      SessionFilter.concluidas => 'Nenhuma sessão concluída ainda.',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: InlineNotice(icon: AppIcons.sessions, message: message),
    );
  }

  Widget _buildCard(TrainingSession session) {
    return SessionCard(
      leading: CompanyLogo.card(
        companyName: session.companyName,
        url: session.companyLogoUrl,
      ),
      companyName: session.companyName,
      courseName: session.courseName,
      meta: session.meta,
      accentColor: session.status.accentColor,
      statusChip: StatusChip(
        label: session.status.label,
        icon: session.status.icon,
        tone: session.status.tone,
      ),
      progressValue: session.progress,
      progressLabel: session.progressLabel,
      selected: session.id == widget.selectedSessionId,
      onTap: () {
        final open = widget.onOpenSession;
        if (open != null) {
          open(session.id);
        } else {
          context.push(AppRoutes.sessionDetail(session.id));
        }
      },
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      key: const Key('sessions-skeleton'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 180, height: 18),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(width: 220),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(width: 140, height: 12),
          ],
        ),
      ),
    );
  }
}
