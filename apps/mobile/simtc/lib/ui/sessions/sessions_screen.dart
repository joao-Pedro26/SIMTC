import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/training_session.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/filter_chip_bar.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/pill_nav_bar.dart';
import '../core/widgets/session_card.dart';
import '../core/widgets/skeleton.dart';
import '../core/widgets/status_chip.dart';
import 'session_filter.dart';
import 'sessions_list_viewmodel.dart';

/// Tela 1.3 — a Home do app.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late final SessionsListViewModel _viewModel = SessionsListViewModel(
    repository: context.read<SessionRepository>(),
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

    // No fim absoluto do scroll, a última seção ("Concluídas") pode ser curta
    // demais para o cabeçalho dela cruzar a linha de ativação — não há
    // conteúdo abaixo dela pra "empurrá-la" pra cima do topo da área rolável.
    // Sem este caso especial, o chip ficaria preso na seção anterior mesmo
    // com "Concluídas" inteira na tela. Aqui o critério vira só "está
    // montada", não "cruzou a linha".
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 1) {
      for (final filter in SessionFilter.values.reversed) {
        final box = sectionBox(filter);
        if (box != null && box.attached) {
          active = filter;
          break;
        }
      }
    }

    // Quando nenhuma seção cruzou a linha (topo absoluto da lista, ou um
    // fling rápido que passa por este listener antes do layout assentar), o
    // filtro ativo cai para "Hoje" em vez de ficar preso na última seção que
    // alguma vez foi destacada.
    _viewModel.setFilter(active ?? SessionFilter.hoje);
  }

  Widget _buildScaffold(BuildContext context, SessionsListViewModel viewModel) {
    final isOffline = context.watch<ConnectivityService>().isOffline;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            ConnectivityBanner(
              isOffline: isOffline,
              message: _offlineMessage(viewModel.lastSyncedAt),
            ),
            _buildFilters(viewModel),
            Expanded(child: _buildBody(viewModel)),
          ],
        ),
      ),
      bottomNavigationBar: _buildNavBar(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;
    final title = user?.isAdmin == true ? 'Sessões' : 'Minhas sessões';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
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
              _buildSyncIndicator(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(_greeting(user?.name), style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.xxs),
          // O key desambigua o título do rótulo 'Sessões' da navbar, que tem o
          // mesmo texto quando o usuário é ADMIN.
          Text(
            title,
            key: const Key('sessions-title'),
            style: AppTypography.screenTitle,
          ),
        ],
      ),
    );
  }

  /// Sem conexão, o consultor precisa saber a idade do que está vendo — uma
  /// lista de ontem parece igualzinha a uma de agora. Devolve nulo quando o
  /// cache nunca foi preenchido, e aí a faixa usa a mensagem padrão dela.
  String? _offlineMessage(DateTime? lastSyncedAt) {
    if (lastSyncedAt == null) return null;

    String two(int value) => value.toString().padLeft(2, '0');
    final d = lastSyncedAt;
    return 'Sem conexão — dados de ${two(d.day)}/${two(d.month)} '
        'às ${two(d.hour)}:${two(d.minute)}.';
  }

  /// Indicador de avaliações esperando envio. Fica sem badge até a Fase 4 criar
  /// a fila local; já existe para o consultor aprender onde olhar.
  Widget _buildSyncIndicator() {
    return const SizedBox(
      width: AppSpacing.touchTarget,
      height: AppSpacing.touchTarget,
      child: Icon(AppIcons.syncDone, color: AppColors.text3),
    );
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
          for (final section in viewModel.sections)
            ..._buildSection(viewModel, section),
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.sm + 2,
        ),
        child: Text(
          section.title,
          style: AppTypography.meta.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      if (section.isEmpty)
        _buildSectionEmpty(section.filter)
      else
        for (final block in section.blocks) ..._buildBlock(viewModel, block),
    ];
  }

  List<Widget> _buildBlock(SessionsListViewModel viewModel, SessionBlock block) {
    return [
      if (block.title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xs,
          ),
          child: Text(
            block.title!,
            style: AppTypography.meta.copyWith(fontWeight: FontWeight.w600),
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
            AppSpacing.sm,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SessionCard(
        companyName: session.companyName,
        courseName: session.courseName,
        meta: session.meta,
        accentColor: _accentFor(session.status),
        statusChip: StatusChip(
          label: session.status.label,
          icon: _iconFor(session.status),
          tone: _toneFor(session.status),
        ),
        progressValue: session.progress,
        progressLabel: session.progressLabel,
        // O detalhe da sessão é a Fase 3; até lá o card não navega.
        onTap: null,
      ),
    );
  }

  Color _accentFor(SessionStatus status) => switch (status) {
        SessionStatus.planejado => AppColors.border,
        SessionStatus.emAndamento => AppColors.primary,
        SessionStatus.concluido => AppColors.successBorder,
        SessionStatus.cancelado => AppColors.dangerBorder,
      };

  StatusTone _toneFor(SessionStatus status) => switch (status) {
        SessionStatus.planejado => StatusTone.neutral,
        SessionStatus.emAndamento => StatusTone.info,
        SessionStatus.concluido => StatusTone.success,
        SessionStatus.cancelado => StatusTone.danger,
      };

  IconData _iconFor(SessionStatus status) => switch (status) {
        SessionStatus.planejado => AppIcons.pending,
        SessionStatus.emAndamento => AppIcons.inProgress,
        SessionStatus.concluido => AppIcons.approved,
        SessionStatus.cancelado => AppIcons.needsReview,
      };

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

  Widget _buildNavBar(BuildContext context) {
    return PillNavBar(
      currentIndex: 0,
      items: const [
        PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
        PillNavItem(icon: AppIcons.sync, label: 'Sincronizar'),
        PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
      ],
      onSelect: (index) {
        if (index == 0) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disponível em breve.')),
        );
      },
    );
  }
}
