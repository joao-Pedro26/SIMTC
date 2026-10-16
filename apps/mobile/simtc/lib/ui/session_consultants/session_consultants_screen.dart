import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/session_consultant.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_consultant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
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
/// Diferenças do canvas, aprovadas em 09/10/2026: sem a lupa (a busca é da
/// Fase 8); o e-mail no lugar da agenda de quem está na equipe (o backend não
/// tem agenda de consultor); a confirmação antes de remover quem tem
/// avaliação em andamento; e os botões com 48dp (o quadro tem 44).
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

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;
    final error = _viewModel.errorMessage;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(title: 'Consultores'),
            ConnectivityBanner(
              isOffline: isOffline,
              message: 'Sem conexão — mudar os consultores precisa de internet.',
            ),
            // Fora da rolagem: a falha de um botão do fim da lista não pode
            // ficar escondida lá em cima.
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: InlineNotice(
                  icon: AppIcons.needsReview,
                  message: error,
                  tone: NoticeTone.danger,
                ),
              ),
            Expanded(child: _buildBody(isOffline)),
          ],
        ),
      ),
    );
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

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _viewModel.refresh,
      child: ListView(
        // Explícito pelo mesmo motivo do detalhe: puxar para atualizar precisa
        // funcionar mesmo quando a lista é mais curta que a tela.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SessionContextHeader(
            companyName: session.companyName,
            logoUrl: session.companyLogoUrl,
            title: _viewModel.contextTitle,
            subtitle: _viewModel.contextSubtitle,
            muted: true,
          ),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                0,
              ),
              child: notice,
            ),
          _buildSessionTitle(),
          for (final item in _viewModel.inSession)
            _buildSessionRow(item, enabled),
          _buildTeamTitle(),
          ..._buildTeam(enabled),
          _buildFooterNote(),
        ],
      ),
    );
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl + AppSpacing.xxs,
        AppSpacing.xl,
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
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
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: InlineNotice(
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
      children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
    );
  }
}
