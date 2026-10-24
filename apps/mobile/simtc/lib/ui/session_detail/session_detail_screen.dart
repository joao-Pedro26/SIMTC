import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_consultant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../router.dart';
import '../core/date_labels.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/company_logo.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/filter_chip_bar.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/skeleton.dart';
import '../core/widgets/status_chip.dart';
import '../core/widgets/sync_status_indicator.dart';
import '../sessions/session_status_style.dart';
import 'participant_filter.dart';
import 'participant_row.dart';
import 'session_detail_viewmodel.dart';

/// Tela 1.4 — detalhe da sessão, com a lista de participantes.
///
/// No tablet, o recuo das laterais passa de 16/20 para 24 (quadros "4c" e
/// "4e"). Em paisagem a tela é o painel da direita, ao lado da lista
/// ([embedded]): sem a barra de topo, com as ações do ADMIN na linha da
/// empresa e o progresso à direita (quadros "4c" e "4d").
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    this.embedded = false,
    this.onBack,
  });

  final String sessionId;

  /// Painel ao lado da lista (tablet em paisagem).
  final bool embedded;

  /// O voltar da barra de topo. Sem ele, desempilha a tela.
  final VoidCallback? onBack;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final SessionDetailViewModel _viewModel = SessionDetailViewModel(
    sessionId: widget.sessionId,
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    assessmentRepository: context.read<AssessmentRepository>(),
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

  /// Mesmo padrão da Home: o aviso é passageiro, a lista continua válida. A
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

  /// Recuo das laterais da lista: 20 no celular, 24 no tablet.
  double get _inset => context.isTablet ? AppSpacing.xxl : AppSpacing.xl;

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.embedded)
              AppTopBar(
                title: 'Detalhe da sessão',
                onBack: widget.onBack,
                actions: [
                  if (_viewModel.isAdmin) ..._buildAdminActions(isOffline),
                ],
                trailing: SyncStatusIndicator(
                  onTap: () => context.go(AppRoutes.sync),
                ),
              ),
            ConnectivityBanner(
              isOffline: isOffline,
              message: offlineDataMessage(
                _viewModel.session?.participantsSyncedAt,
              ),
            ),
            Expanded(child: _buildBody(isOffline)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAdminActions(bool isOffline) {
    return [
      AppIconAction(
        icon: AppIcons.edit,
        tooltip: 'Editar dados do treinamento',
        highlighted: _openAdmin == _AdminScreen.edit,
        onPressed: _adminActionsEnabled(isOffline) ? _openEdit : null,
      ),
      // Sempre ligado: sem conexão ou com a sessão encerrada, a tela de lá
      // abre só para leitura.
      AppIconAction(
        icon: AppIcons.consultants,
        tooltip: 'Consultores da sessão',
        highlighted: _openAdmin == _AdminScreen.consultants,
        onPressed: _openConsultants,
      ),
    ];
  }

  /// A tela de admin aberta a partir deste detalhe. No tablet, ela é uma
  /// janela por cima, e o botão que a abriu fica marcado (quadros "4l", "4m"
  /// e "4n").
  _AdminScreen? _openAdmin;

  Future<T?> _pushAdmin<T>(_AdminScreen screen, String location) async {
    // No celular, a tela de admin cobre o detalhe: não há o que marcar.
    if (context.isTablet) setState(() => _openAdmin = screen);
    try {
      return await context.push<T>(location);
    } finally {
      if (mounted) setState(() => _openAdmin = null);
    }
  }

  /// As ações de ADMIN (canvas "1f") precisam de conexão e de uma sessão
  /// que ainda aceite mudanças. Sem isso, continuam à vista, apagadas — e o
  /// aviso da lista diz o motivo.
  bool _adminActionsEnabled(bool isOffline) =>
      _viewModel.adminActionsAllowed && !isOffline;

  /// Salvou lá: baixa a sessão de novo, para ficar com o estado oficial do
  /// servidor. (Se a sessão foi cancelada, a tela de lá já levou o ADMIN para
  /// a lista, e este detalhe nem existe mais.)
  Future<void> _openEdit() async {
    final saved = await _pushAdmin<bool>(
      _AdminScreen.edit,
      AppRoutes.sessionEdit(widget.sessionId),
    );
    if (saved == true && mounted) unawaited(_viewModel.refresh());
  }

  /// Quem entra ou sai por lá muda o cache, e este detalhe lê do cache: não
  /// há o que fazer na volta.
  Future<void> _openConsultants() async {
    await _pushAdmin<Object?>(
      _AdminScreen.consultants,
      AppRoutes.sessionConsultants(widget.sessionId),
    );
  }

  /// Entrou gente lá: a linha nova já está no cache, e baixar de novo acerta
  /// os contadores.
  Future<void> _openAddParticipant() async {
    final added = await _pushAdmin<bool>(
      _AdminScreen.addParticipant,
      AppRoutes.addParticipant(widget.sessionId),
    );
    if (added == true && mounted) unawaited(_viewModel.refresh());
  }

  Widget _buildBody(bool isOffline) {
    if (_viewModel.isLoading) return _buildSkeleton();

    final session = _viewModel.session;
    if (session == null) return _buildMissingSession();

    // Cabeçalho e chips fixos, lista rolando embaixo — como no canvas.
    return Column(
      children: [
        _buildSessionHeader(session, isOffline),
        _buildFilters(),
        Expanded(child: _buildParticipantList(session, isOffline)),
      ],
    );
  }

  /// Tablet: 16 em cima, 18 embaixo, 24 dos lados e 14 entre as partes; no
  /// celular, 14/16/16 e 12.
  Widget _buildSessionHeader(TrainingSession session, bool isOffline) {
    final notes = session.notes?.trim() ?? '';
    final progress = _viewModel.progress;
    final tablet = context.isTablet;
    final gap = tablet ? AppSpacing.md + 2 : AppSpacing.md;
    // Em paisagem o progresso sai da pilha e vai para a direita (do nome da
    // empresa, ou da linha de local e data quando há as ações do ADMIN).
    final inlineProgress = widget.embedded && progress.fraction != null;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: tablet
          ? const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.xxl,
              AppSpacing.lg + 2,
            )
          : const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md + 2,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCompanyRow(
            session,
            isOffline,
            trailingProgress: inlineProgress && !_viewModel.isAdmin,
          ),
          SizedBox(height: gap),
          _buildMetaRow(
            session,
            trailingProgress: inlineProgress && _viewModel.isAdmin,
          ),
          if (notes.isNotEmpty) ...[
            SizedBox(height: gap),
            InlineNotice(icon: AppIcons.notes, message: notes),
          ],
          if (progress.fraction != null && !inlineProgress) ...[
            SizedBox(height: gap),
            _buildProgress(progress),
          ],
          if (_viewModel.canStartSession) ...[
            SizedBox(height: gap),
            _buildStartButton(isOffline),
          ],
        ],
      ),
    );
  }

  /// O progresso de 240 de largura do painel em paisagem.
  static const double _inlineProgressWidth = 240;

  Widget _buildCompanyRow(
    TrainingSession session,
    bool isOffline, {
    required bool trailingProgress,
  }) {
    final tablet = context.isTablet;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tablet
            ? CompanyLogo.headerLarge(
                companyName: session.companyName,
                url: session.companyLogoUrl,
              )
            : CompanyLogo.header(
                companyName: session.companyName,
                url: session.companyLogoUrl,
              ),
        SizedBox(width: tablet ? AppSpacing.md + 2 : AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.companyName,
                style: tablet
                    ? AppTypography.detailTitleTablet
                    : AppTypography.detailTitle,
              ),
              SizedBox(height: tablet ? AppSpacing.xs : AppSpacing.xxs + 1),
              Text(
                session.courseName,
                style: tablet
                    ? AppTypography.detailCourseTablet
                    : AppTypography.body,
              ),
            ],
          ),
        ),
        if (widget.embedded && _viewModel.isAdmin) ...[
          const SizedBox(width: AppSpacing.md + 2),
          ..._buildAdminActions(isOffline),
        ],
        if (trailingProgress) ...[
          const SizedBox(width: AppSpacing.md + 2),
          SizedBox(
            width: _inlineProgressWidth,
            child: _buildProgress(_viewModel.progress, short: true),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaRow(TrainingSession session, {required bool trailingProgress}) {
    final wrap = _buildMetaWrap(session);
    if (!trailingProgress) return wrap;

    return Row(
      children: [
        Expanded(child: wrap),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(
          width: _inlineProgressWidth,
          child: _buildProgress(_viewModel.progress, short: true),
        ),
      ],
    );
  }

  Widget _buildMetaWrap(TrainingSession session) {
    final date = session.date;
    final consultants = _viewModel.consultantsLabel;

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildMetaItem(AppIcons.place, '${session.city}/${session.state}'),
        _buildMetaItem(
          AppIcons.event,
          date == null ? 'Sem data' : dayMonthYearLabel(date),
        ),
        if (consultants != null)
          _buildMetaItem(AppIcons.consultantCount, consultants),
        StatusChip(
          label: session.status.label,
          icon: session.status.icon,
          tone: session.status.tone,
        ),
      ],
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.text3),
        const SizedBox(width: AppSpacing.xs + 1),
        Text(text, style: AppTypography.optionLabel),
      ],
    );
  }

  Widget _buildProgress(ParticipantProgress progress, {bool short = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                short ? progress.shortLabel : progress.label,
                style: AppTypography.meta.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              progress.percentLabel,
              style: AppTypography.meta.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: progress.fraction,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

  /// Não está no canvas: entrou com a regra do web de só avaliar com a sessão
  /// em andamento (decisão de 23/09/2026) — sem ele, o consultor em campo
  /// ficaria travado numa sessão que ninguém iniciou no painel.
  Widget _buildStartButton(bool isOffline) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPrimaryButton(
          label: 'Iniciar sessão',
          icon: AppIcons.startSession,
          isLoading: _viewModel.isStarting,
          onPressed: isOffline ? null : _confirmStart,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          isOffline
              ? 'Iniciar a sessão precisa de conexão.'
              : 'Inicie a sessão para atribuir e avaliar participantes.',
          style: AppTypography.meta,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _confirmStart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Iniciar a sessão?'),
        content: const Text(
          'Com a sessão em andamento, os consultores podem atribuir e avaliar '
          'participantes. O painel web passa a mostrá-la como "Em andamento".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _viewModel.startSession();
  }

  Widget _buildFilters() {
    final counts = _viewModel.counts;

    return Container(
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: FilterChipBar(
        items: [
          for (final filter in ParticipantFilter.values)
            FilterChipData(label: filter.label, count: counts[filter]),
        ],
        selectedIndex: ParticipantFilter.values.indexOf(_viewModel.filter),
        onSelect: (index) =>
            _viewModel.setFilter(ParticipantFilter.values[index]),
        horizontalPadding: _inset,
      ),
    );
  }

  Widget _buildParticipantList(TrainingSession session, bool isOffline) {
    final notice = _buildNotice(session, isOffline);
    final visible = _viewModel.visibleParticipants;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _viewModel.refresh,
      child: ListView(
        // Explícito pelo mesmo motivo da Home: puxar para atualizar precisa
        // funcionar mesmo quando a lista é mais curta que a tela.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.huge),
        children: [
          if (notice != null)
            Padding(
              padding: EdgeInsets.fromLTRB(_inset, AppSpacing.md, _inset, 0),
              child: notice,
            ),
          _buildListHeader(isOffline),
          if (visible.isEmpty)
            _buildEmpty()
          else
            for (final participant in visible)
              _buildParticipant(participant, isOffline),
        ],
      ),
    );
  }

  /// Um aviso por vez, o mais importante primeiro: sem dados baixados, nada
  /// mais importa; depois, por que ninguém pode ser atribuído agora.
  Widget? _buildNotice(TrainingSession session, bool isOffline) {
    if (_viewModel.neverDownloaded) {
      return const InlineNotice(
        icon: AppIcons.noSignal,
        tone: NoticeTone.warning,
        message: 'Os participantes desta sessão ainda não foram baixados. '
            'Puxe para atualizar quando houver conexão.',
      );
    }

    // ADMIN sem conexão, numa sessão que ainda aceita mudanças: o aviso do
    // canvas "1f". Cobre também o "Atribuir a mim", que fica desabilitado.
    if (isOffline && _viewModel.adminActionsAllowed) {
      return const InlineNotice(
        icon: AppIcons.offline,
        tone: NoticeTone.warning,
        message: 'Ações administrativas precisam de conexão. A avaliação '
            'continua funcionando offline.',
      );
    }

    // O ADMIN vê o lápis e o adicionar apagados: o aviso diz por quê.
    final lockedForAdmin = _viewModel.isAdmin
        ? ', e os dados não podem mais ser alterados.'
        : '.';

    switch (session.status) {
      case SessionStatus.planejado:
        // Quem pode iniciar já tem o botão e a explicação no cabeçalho.
        if (_viewModel.canStartSession) return null;
        return const InlineNotice(
          icon: AppIcons.pending,
          message: 'Aguardando o responsável iniciar a sessão para atribuir '
              'e avaliar participantes.',
        );
      case SessionStatus.concluido:
        return InlineNotice(
          icon: AppIcons.approved,
          message: 'Sessão concluída: os participantes ficam só para consulta'
              '$lockedForAdmin',
        );
      case SessionStatus.cancelado:
        return InlineNotice(
          icon: AppIcons.needsReview,
          message: 'Sessão cancelada: os participantes ficam só para consulta'
              '$lockedForAdmin',
        );
      case SessionStatus.emAndamento:
        if (!_viewModel.hasConsultantProfile) {
          return const InlineNotice(
            icon: AppIcons.profile,
            tone: NoticeTone.warning,
            message: 'Seu usuário não tem perfil de consultor: dá para '
                'acompanhar a sessão, mas não avaliar.',
          );
        }
        if (isOffline && _viewModel.hasPendingToAssign) {
          return const InlineNotice(
            icon: AppIcons.offline,
            tone: NoticeTone.warning,
            message: 'Sem conexão: dá para ver a lista e abrir quem já é seu, '
                'mas atribuir precisa de internet.',
          );
        }
        return null;
    }
  }

  Widget _buildListHeader(bool isOffline) {
    final title = Text('Participantes', style: AppTypography.sectionTitle);
    if (!_viewModel.isAdmin) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _inset,
          vertical: AppSpacing.lg - 1,
        ),
        child: title,
      );
    }

    // ADMIN (canvas "1f"): o "adicionar participante" à direita do título. O
    // quadro desenha a linha com 62dp (15 + um alvo de 32 + 15); o alvo de 48dp
    // fecha os mesmos 62 com 7 em cima e 7 embaixo, e o ícone fica à mesma
    // distância do topo. O recuo menor à direita alinha o ícone, e não a área
    // de toque, com a margem da lista.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _inset,
        AppSpacing.sm - 1,
        _inset - AppSpacing.md,
        AppSpacing.sm - 1,
      ),
      child: Row(
        children: [
          Expanded(child: title),
          AppIconAction(
            icon: AppIcons.addParticipant,
            tooltip: 'Adicionar participante',
            highlighted: _openAdmin == _AdminScreen.addParticipant,
            onPressed:
                _adminActionsEnabled(isOffline) ? _openAddParticipant : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    // Nunca baixada: o aviso de cima já explica, e "nenhum participante"
    // seria uma afirmação que o app não tem como fazer.
    if (_viewModel.neverDownloaded) return const SizedBox.shrink();

    final message = !_viewModel.hasParticipants
        ? 'Nenhum participante inscrito nesta sessão.'
        : switch (_viewModel.filter) {
            ParticipantFilter.todos => 'Nenhum participante inscrito nesta sessão.',
            ParticipantFilter.pendentes => 'Nenhum participante pendente.',
            ParticipantFilter.meus => 'Nenhum participante com você.',
            ParticipantFilter.concluidos => 'Nenhum participante avaliado ainda.',
          };

    return Padding(
      padding: EdgeInsets.fromLTRB(_inset, 0, _inset, AppSpacing.md),
      child: InlineNotice(icon: AppIcons.profile, message: message),
    );
  }

  Widget _buildParticipant(SessionParticipant participant, bool isOffline) {
    final situation = _viewModel.situationFor(participant);
    final local = _viewModel.localAssessmentFor(participant.id);
    final progress = _viewModel.localProgressFor(participant);
    final showsLocal = progress == LocalProgress.queued ||
        progress == LocalProgress.failed ||
        progress == LocalProgress.sent;

    return ParticipantRow(
      key: ValueKey('participante-${participant.id}'),
      name: participant.name,
      maskedCpf: participant.maskedCpf,
      chip: showsLocal
          ? _buildQueueChip(progress!)
          : _buildSituationChip(participant, situation),
      // O rascunho mostra só a hora do "Iniciar avaliação": o app não tem
      // cronômetro, só registra início e fim (decisão de 30/09/2026).
      meta: showsLocal
          ? queueMetaFor(local!, _viewModel.now)
          : progress == LocalProgress.draft
              ? startedLabel(local!.startTime, _viewModel.now)
              : assessedAtLabelFor(participant, situation, _viewModel.now),
      blockedNote: blockedNoteFor(participant, situation),
      muted: situation == ParticipantSituation.other,
      horizontalInset: _inset,
      accentColor: situation == ParticipantSituation.mine
          ? AppColors.primary
          : AppColors.border,
      onTap: _tapActionFor(participant),
      action: _viewModel.canAssign(participant)
          ? _buildAssignButton(participant, isOffline)
          : null,
      menu: _viewModel.showsAdminMenu(participant)
          ? _buildAdminMenu(participant, isOffline)
          : null,
    );
  }

  /// ⋮ do ADMIN na linha de quem está com outro consultor (decisão de
  /// 09/10/2026 — não está no canvas): "Desatribuir participante". Segue a
  /// regra das ações de ADMIN: sem conexão ou com a sessão encerrada, fica à
  /// vista, apagado, e o aviso da lista diz por quê. Com um desatribuir no ar,
  /// a linha dele gira e os outros menus não abrem.
  Widget _buildAdminMenu(SessionParticipant participant, bool isOffline) {
    final unassigning = _viewModel.unassigningParticipantId;
    if (unassigning == participant.id) {
      return SizedBox.square(
        key: ValueKey('desatribuindo-${participant.id}'),
        dimension: AppSpacing.touchTarget,
        child: const Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.text3),
            ),
          ),
        ),
      );
    }

    final enabled = _adminActionsEnabled(isOffline) && unassigning == null;
    return SizedBox.square(
      dimension: AppSpacing.touchTarget,
      child: PopupMenuButton<_RowAction>(
        key: ValueKey('menu-${participant.id}'),
        tooltip: 'Mais opções',
        enabled: enabled,
        icon: Icon(
          AppIcons.more,
          color: enabled ? AppColors.text : AppColors.textMuted,
        ),
        onSelected: (_) => _confirmUnassign(participant),
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _RowAction.unassign,
            child: Text('Desatribuir participante'),
          ),
        ],
      ),
    );
  }

  /// Volta para "Pendente" ou, numa reavaliação, para "Não recomendado" — a
  /// mesma regra do backend.
  Future<void> _confirmUnassign(SessionParticipant participant) async {
    final consultant = participant.assignedConsultantName?.trim() ?? '';
    final withWhom = consultant.isEmpty ? 'outro consultor' : consultant;
    final status =
        participant.hasPreviousAssessment ? 'Não recomendado' : 'Pendente';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Desatribuir ${participant.name}?'),
        content: Text(
          'Está em avaliação com $withWhom. Ao desatribuir, volta para '
          '$status e pode ser avaliado por outro consultor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desatribuir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _viewModel.unassignAsAdmin(participant.id);
    }
  }

  /// Para onde a linha leva: o checklist (Fase 4) ou o Resultado (Fase 5B) —
  /// também o da avaliação confirmada neste aparelho. Os dois leem o
  /// participante do banco, por isso não recebem `extra`.
  VoidCallback? _tapActionFor(SessionParticipant participant) {
    if (_viewModel.opensChecklist(participant)) {
      return () => context.push(
            AppRoutes.participantChecklist(widget.sessionId, participant.id),
          );
    }
    if (_viewModel.opensResult(participant)) {
      return () => context.push(
            AppRoutes.participantResult(widget.sessionId, participant.id),
          );
    }
    return null;
  }

  Widget _buildAssignButton(SessionParticipant participant, bool isOffline) {
    final assigning = _viewModel.assigningParticipantId;

    return AppCtaButton(
      key: ValueKey('atribuir-${participant.id}'),
      label: 'Atribuir a mim',
      icon: AppIcons.assign,
      isLoading: assigning == participant.id,
      // Um de cada vez, e nunca offline: a reserva é feita no servidor.
      onPressed: isOffline || assigning != null
          ? null
          : () => _viewModel.assign(participant.id),
    );
  }

  Widget _buildSituationChip(
    SessionParticipant participant,
    ParticipantSituation situation,
  ) {
    final (icon, tone) = switch (situation) {
      ParticipantSituation.mine => (AppIcons.evaluating, StatusTone.info),
      ParticipantSituation.pending => (AppIcons.notStarted, StatusTone.neutral),
      ParticipantSituation.other => (AppIcons.lockedByOther, StatusTone.neutral),
      ParticipantSituation.approved => (AppIcons.approved, StatusTone.success),
      ParticipantSituation.needsReview => (AppIcons.needsReview, StatusTone.danger),
      ParticipantSituation.theoryOnly => (AppIcons.theoryOnly, StatusTone.mauve),
    };

    return StatusChip(
      label: chipLabelFor(participant, situation),
      icon: icon,
      tone: tone,
      dashedBorder: situation == ParticipantSituation.other,
    );
  }

  /// Confirmada e esperando o servidor, ou já aceita mas a sessão ainda não
  /// foi baixada de novo (decisão de 29/09/2026 e revisão de 30/09/2026): a
  /// mesma pílula "Na fila" da aba Sincronizar, "Erro no envio" se o último
  /// envio falhou, ou "Enviada" se já foi aceita. O canvas não tem estes
  /// estados. (O rascunho nunca chega aqui: mostra a hora de início, não a fila.)
  Widget _buildQueueChip(LocalProgress progress) {
    return switch (progress) {
      LocalProgress.failed => const StatusChip(
          label: 'Erro no envio',
          icon: AppIcons.sendFailed,
          tone: StatusTone.danger,
        ),
      LocalProgress.sent => const StatusChip(
          label: 'Enviada',
          icon: AppIcons.syncDone,
          tone: StatusTone.info,
        ),
      LocalProgress.draft || LocalProgress.queued => const StatusChip(
          label: 'Na fila',
          icon: AppIcons.pending,
          tone: StatusTone.neutral,
        ),
    };
  }

  Widget _buildSkeleton() {
    return ListView(
      key: const Key('session-detail-skeleton'),
      children: const [
        SkeletonListItem(),
        SkeletonListItem(),
        SkeletonListItem(),
        SkeletonListItem(),
      ],
    );
  }

  Widget _buildMissingSession() {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: InlineNotice(
        icon: AppIcons.sessions,
        message: 'Esta sessão não está mais disponível neste aparelho. '
            'Volte para a lista de sessões.',
      ),
    );
  }
}

/// O que o ⋮ de uma linha oferece ao ADMIN.
enum _RowAction { unassign }

/// As telas de admin que o detalhe abre (ver `_openAdmin`).
enum _AdminScreen { edit, consultants, addParticipant }
