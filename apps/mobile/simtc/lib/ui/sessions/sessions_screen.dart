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

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_showErrorWhenItArrives);
  }

  @override
  void dispose() {
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
        onSelect: (index) => viewModel.setFilter(SessionFilter.values[index]),
      ),
    );
  }

  Widget _buildBody(SessionsListViewModel viewModel) {
    if (viewModel.isLoading) return _buildSkeleton();

    final groups = viewModel.groups;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: viewModel.refresh,
      child: groups.isEmpty
          ? _buildEmptyState(viewModel)
          : ListView(
              // Explícito por segurança: um `ListView` sem `controller` já é
              // "primary" e ganha essa física por padrão, mas deixar
              // implícito depende desse detalhe do framework — um
              // `controller` adicionado aqui no futuro desligaria o padrão
              // e devolveria o pull-to-refresh quebrado numa lista curta.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.huge * 2,
              ),
              children: [
                for (final group in groups) ..._buildGroup(group),
              ],
            ),
    );
  }

  List<Widget> _buildGroup(SessionGroup group) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.sm + 2,
        ),
        child: Text(
          group.title,
          style: AppTypography.meta.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      for (final session in group.sessions) _buildCard(session),
    ];
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

  /// A lista precisa rolar mesmo vazia, senão o pull-to-refresh não tem o que
  /// arrastar — e é justamente quando está vazia que o consultor puxa.
  Widget _buildEmptyState(SessionsListViewModel viewModel) {
    final message = switch (viewModel.filter) {
      SessionFilter.hoje => 'Nenhuma sessão para hoje.',
      SessionFilter.proximos7 => 'Nada agendado para os próximos 7 dias.',
      SessionFilter.concluidas => 'Nenhuma sessão concluída ainda.',
    };

    return ListView(
      key: const Key('sessions-empty'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.huge),
        InlineNotice(
          icon: AppIcons.sessions,
          message: '$message Puxe para atualizar.',
        ),
      ],
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
