import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/session_consultant.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_consultant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/admin_dialog.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_search_field.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/session_context_header.dart';
import '../core/widgets/skeleton.dart';
import '../core/widgets/status_chip.dart';
import 'consultant_row.dart';
import 'session_consultants_viewmodel.dart';

/// Tela 1.13 — "Consultores" (quadro "3c" do canvas), só para ADMIN.
///
/// Diferenças do canvas, aprovadas em 09/10/2026: o e-mail no lugar da agenda
/// de quem está na equipe (o backend não tem agenda de consultor); a
/// confirmação antes de remover quem tem avaliação em andamento; e os botões
/// com 48dp (o quadro tem 44). A lupa do quadro busca pelo nome (Fase 8B); no
/// tablet ela fica no cabeçalho da janela, ao lado do X (os quadros "4n" e
/// "4y" não a desenham).
class SessionConsultantsScreen extends StatefulWidget {
  const SessionConsultantsScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionConsultantsScreen> createState() =>
      _SessionConsultantsScreenState();
}

class _SessionConsultantsScreenState extends State<SessionConsultantsScreen> {
  late final SessionConsultantsViewModel _viewModel =
      SessionConsultantsViewModel(
    sessionId: widget.sessionId,
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    consultantRepository: context.read<SessionConsultantRepository>(),
    connectivity: context.read<ConnectivityService>(),
    currentUser: context.read<AuthRepository>().currentUser,
  )..init();

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

  /// Mesmo padrão do detalhe: o aviso de quem entrou ou saiu é passageiro. A
  /// mensagem é limpa assim que é agendada — limpar antes de agendar também
  /// evita reentrância, já que `clearMessage()` notifica de novo.
  void _showMessageWhenItArrives() {
    final message = _viewModel.message;
    if (message == null) return;
    _viewModel.clearMessage();

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
      builder: (context, _) => _buildScaffold(context),
    );
  }

  /// Recuo das laterais: 20 no celular, 24 na janela do tablet (quadro "4n").
  double get _inset => context.isTablet ? AppSpacing.xxl : AppSpacing.xl;

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;

    // O voltar (o do Android, a seta e o X da janela) fecha a busca antes de
    // fechar a tela.
    return PopScope(
      canPop: !_viewModel.isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _viewModel.isSearching) _viewModel.closeSearch();
      },
      child: context.isTablet
          ? _buildDialog(isOffline)
          : _buildPage(isOffline),
    );
  }

  Widget _buildPage(bool isOffline) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Consultores',
              trailing: _viewModel.isSearching ? null : _buildSearchButton(),
            ),
            if (_viewModel.isSearching) _buildSearchField(),
            ..._buildBanners(isOffline),
            Expanded(child: _buildBody(isOffline)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton() =>
      AppSearchButton(onPressed: _viewModel.openSearch);

  /// O campo abre embaixo do cabeçalho, com o recuo da lista.
  Widget _buildSearchField() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _inset,
        vertical: AppSpacing.sm,
      ),
      child: AppSearchField(
        hintText: 'Buscar consultor pelo nome',
        initialText: _viewModel.searchQuery,
        onChanged: _viewModel.setSearchQuery,
        onClose: _viewModel.closeSearch,
      ),
    );
  }

  /// No tablet, a tela é uma janela por cima do detalhe (quadros "4n" e
  /// "4y"), sem rodapé: cada toque vale na hora. A lista é a do celular.
  Widget _buildDialog(bool isOffline) {
    return AdminDialogFrame(
      title: 'Consultores da sessão',
      subtitle: 'Cada toque vale na hora — não há botão de salvar.',
      onClose: () => Navigator.of(context).maybePop(),
      actions: [if (!_viewModel.isSearching) _buildSearchButton()],
      banner: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_viewModel.isSearching) _buildSearchField(),
          ..._buildBanners(isOffline),
        ],
      ),
      body: _buildBody(isOffline),
    );
  }

  /// A faixa de sem conexão e a falha do último toque — fora da rolagem: a
  /// falha de um botão do fim da lista não pode ficar escondida lá em cima.
  List<Widget> _buildBanners(bool isOffline) {
    final error = _viewModel.errorMessage;

    return [
      ConnectivityBanner(
        isOffline: isOffline,
        message: 'Sem conexão — mudar os consultores precisa de internet.',
      ),
      if (error != null)
        Padding(
          padding: EdgeInsets.fromLTRB(_inset, AppSpacing.md, _inset, AppSpacing.md),
          child: InlineNotice(
            icon: AppIcons.needsReview,
            message: error,
            tone: NoticeTone.danger,
          ),
        ),
    ];
  }

  Widget _buildBody(bool isOffline) {
    if (_viewModel.isLoading) return _buildSkeleton();

    final session = _viewModel.session;
    if (session == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: InlineNotice(
          icon: AppIcons.sessions,
          message: _viewModel.lockedReason ?? '',
        ),
      );
    }

    // Entrar e sair precisam de conexão, de uma sessão que aceite mudanças e
    // de nenhum outro envio no ar. Fora disso os botões continuam à vista,
    // apagados — a faixa, o aviso ou o indicador dizem por quê.
    final enabled = _viewModel.canChange &&
        !isOffline &&
        _viewModel.busyConsultantId == null;
    final notice = _buildNotice();

    final tablet = context.isTablet;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _viewModel.refresh,
      child: ListView(
        // Explícito pelo mesmo motivo do detalhe: puxar para atualizar precisa
        // funcionar mesmo quando a lista é mais curta que a tela.
        physics: const AlwaysScrollableScrollPhysics(),
        // Na janela do tablet, a lista tem a altura do que mostra.
        shrinkWrap: tablet,
        children: [
          // Na janela do tablet, sem a faixa da empresa: a janela fica por
          // cima do detalhe da sessão.
          if (!tablet)
            SessionContextHeader(
              companyName: session.companyName,
              logoUrl: session.companyLogoUrl,
              title: _viewModel.contextTitle,
              subtitle: _viewModel.contextSubtitle,
              muted: true,
            ),
          if (notice != null)
            Padding(
              padding: EdgeInsets.fromLTRB(_inset, AppSpacing.md, _inset, 0),
              child: notice,
            ),
          ..._buildLists(enabled),
          _buildFooterNote(),
        ],
      ),
    );
  }

  /// As duas listas. Com a busca filtrando, a lista sem ninguém some com o
  /// título — a não ser que a equipe tenha um aviso próprio (sem conexão,
  /// todos já na sessão), que vence a busca; sem ninguém nas duas, uma frase
  /// diz que não achou (decisões de 24/10/2026).
  List<Widget> _buildLists(bool enabled) {
    final inSession = _viewModel.inSession;
    final filtering = _viewModel.isFiltering;
    final showTeam = !filtering ||
        _viewModel.available.isNotEmpty ||
        _viewModel.isTeamLoading ||
        _viewModel.teamNotice != null;

    return [
      if (filtering && inSession.isEmpty && _viewModel.available.isEmpty)
        Padding(
          key: const Key('consultants-no-results'),
          padding: EdgeInsets.fromLTRB(_inset, AppSpacing.md, _inset, 0),
          child: InlineNotice(
            icon: AppIcons.search,
            message: 'Nenhum consultor encontrado para '
                '“${_viewModel.searchQuery.trim()}”.',
          ),
        ),
      if (!filtering || inSession.isNotEmpty) ...[
        _buildSessionTitle(),
        for (final item in inSession) _buildSessionRow(item, enabled),
      ],
      if (showTeam) ...[
        _buildTeamTitle(),
        ..._buildTeam(enabled),
      ],
    ];
  }

  /// Um aviso por vez: sem os consultores no aparelho, nada mais importa;
  /// depois, por que a lista está travada.
  Widget? _buildNotice() {
    if (_viewModel.notDownloaded) {
      return const InlineNotice(
        icon: AppIcons.noSignal,
        tone: NoticeTone.warning,
        message: 'Os consultores desta sessão ainda não foram baixados. '
            'Puxe para atualizar quando houver conexão.',
      );
    }
    final lockedReason = _viewModel.lockedReason;
    if (lockedReason == null) return null;
    return InlineNotice(icon: AppIcons.lockedByOther, message: lockedReason);
  }

  Widget _buildSessionTitle() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _inset,
        vertical: AppSpacing.lg - 1,
      ),
      child: Text('Na sessão', style: AppTypography.sectionTitle),
    );
  }

  Widget _buildSessionRow(SessionConsultantItem item, bool enabled) {
    return ConsultantRow(
      key: ValueKey('consultor-${item.id}'),
      name: item.displayName,
      meta: item.meta,
      metaWraps: true,
      horizontalInset: _inset,
      trailing: LabelPill(
        label: item.isResponsible ? 'Responsável' : 'Consultor',
        tone: item.isResponsible ? StatusTone.info : StatusTone.neutral,
      ),
      note: item.note,
      // O responsável não sai por aqui: trocar o responsável é do painel web.
      action: item.removable
          ? AppDangerOutlineButton(
              key: ValueKey('remover-${item.id}'),
              label: 'Remover da sessão',
              icon: AppIcons.removeConsultant,
              compact: true,
              isLoading: _viewModel.busyConsultantId == item.id,
              onPressed: enabled ? () => _remove(item) : null,
            )
          : null,
    );
  }

  /// "Disponíveis na equipe", com o nome da equipe à direita (canvas "3c").
  Widget _buildTeamTitle() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _inset,
        AppSpacing.xl + AppSpacing.xxs,
        _inset,
        AppSpacing.md - AppSpacing.xxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              'Disponíveis na equipe',
              style: AppTypography.sectionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'SIM Treinamentos',
            style: AppTypography.meta.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// A equipe vem do servidor: enquanto não chega, o esqueleto; se não der
  /// para trazer, o motivo no lugar dela.
  List<Widget> _buildTeam(bool enabled) {
    if (_viewModel.isTeamLoading) {
      return const [
        SkeletonListItem(key: Key('equipe-skeleton')),
        SkeletonListItem(),
      ];
    }

    final notice = _viewModel.teamNotice;
    if (notice != null) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _inset),
          child: InlineNotice(icon: AppIcons.info, message: notice),
        ),
      ];
    }

    return [
      for (final consultant in _viewModel.available)
        _buildTeamRow(consultant, enabled),
    ];
  }

  Widget _buildTeamRow(SessionConsultant consultant, bool enabled) {
    return ConsultantRow(
      key: ValueKey('equipe-${consultant.id}'),
      name: consultant.name,
      // O e-mail, e não a agenda do quadro: o backend não tem agenda de
      // consultor (decisão de 09/10/2026).
      meta: consultant.email,
      horizontalInset: _inset,
      trailing: AppCompactOutlineButton(
        key: ValueKey('adicionar-${consultant.id}'),
        label: 'Adicionar',
        icon: AppIcons.addConsultant,
        isLoading: _viewModel.busyConsultantId == consultant.id,
        onPressed: enabled ? () => _viewModel.add(consultant.id) : null,
      ),
    );
  }

  Widget _buildFooterNote() {
    return Padding(
      padding: EdgeInsets.fromLTRB(_inset, AppSpacing.lg, _inset, AppSpacing.xxl),
      child: const InlineNotice(
        icon: AppIcons.syncDone,
        message: 'Entrar e sair da sessão vale na hora e precisa de conexão. '
            'Offline, a lista fica só de leitura.',
      ),
    );
  }

  /// Quem tem avaliação em andamento perde os participantes ao sair: a
  /// consequência vem num diálogo, antes do toque que remove (não está no
  /// canvas — decisão de 09/10/2026). Sem avaliação em andamento, sai direto.
  Future<void> _remove(SessionConsultantItem item) async {
    final consequence = item.note;
    if (consequence != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Remover ${item.name} da sessão?'),
          content: Text(consequence),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remover'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    await _viewModel.remove(item.id);
  }

  Widget _buildSkeleton() {
    return ListView(
      key: const Key('session-consultants-skeleton'),
      shrinkWrap: context.isTablet,
      children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
    );
  }
}
