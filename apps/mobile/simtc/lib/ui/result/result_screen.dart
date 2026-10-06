import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/local/app_database.dart';
import '../../router.dart';
import '../checklist/checklist_badges.dart';
import '../checklist/checklist_sections.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/final_score_block.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/skeleton.dart';
import 'result_details.dart';
import 'result_viewmodel.dart';

/// Tela 1.8 — Resultado ("Avaliação concluída", quadro "2g" do canvas),
/// adaptada em 01/10/2026: sem pontos, com início e fim no lugar da duração,
/// o número do item em cada infração, o aviso de envio e o "Reavaliar".
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.sessionId,
    required this.participantId,
    this.justConfirmed = false,
  });

  final String sessionId;
  final String participantId;

  /// Aberta logo depois do "Confirmar" da tela 1.6: o rodapé é o "Próximo
  /// participante".
  final bool justConfirmed;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final ResultViewModel _viewModel = _createViewModel()..init();

  /// Categorias abertas em "Infrações registradas". Começa com a primeira que
  /// tem infração, como no canvas; nulo até os dados chegarem.
  Set<String>? _open;

  ResultViewModel _createViewModel() {
    // A rota só abre com sessão (redirecionamento do `router.dart`).
    final user = context.read<AuthRepository>().currentUser!;
    return ResultViewModel(
      sessionId: widget.sessionId,
      participantId: widget.participantId,
      ownerUserId: user.id,
      consultantId: user.consultantId,
      justConfirmed: widget.justConfirmed,
      assessmentRepository: context.read<AssessmentRepository>(),
      participantRepository: context.read<ParticipantRepository>(),
      catalogRepository: context.read<AssessmentCatalogRepository>(),
      sessionRepository: context.read<SessionRepository>(),
      connectivity: context.read<ConnectivityService>(),
    );
  }

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
    final footer = _buildFooter(isOffline);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(
              title: 'Avaliação concluída',
              leadingIcon: AppIcons.close,
              leadingIconSize: 26,
              leadingTooltip: 'Fechar',
            ),
            Expanded(child: _buildBody()),
            if (footer != null) footer,
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return ListView(
        key: const Key('result-skeleton'),
        children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
      );
    }

    final categories = _viewModel.categories;
    final withScore = [
      for (final category in categories ?? const <ResultCategory>[])
        if (category.score != null) category,
    ];
    final count = _viewModel.infractionCount;

    return ListView(
      children: [
        _buildScore(),
        ..._buildNotices(),
        if (withScore.isNotEmpty) ...[
          _buildSectionHeader('Desempenho por categoria'),
          _buildPerformance(withScore),
        ],
        if (categories != null) ...[
          _buildSectionHeader(
            'Infrações registradas',
            trailing: count == 0 ? null : infractionCountLabel(count),
          ),
          ..._buildInfractions(categories),
        ],
      ],
    );
  }

  /// "Ana Paula Ribeiro · 042.118.***-** · Início 08:12 · Fim 08:31".
  Widget _buildScore() {
    final participant = _viewModel.participant;
    final detail = [
      if (participant != null && participant.name.isNotEmpty) participant.name,
      if (participant != null) participant.maskedCpf,
      if (_viewModel.timesLabel case final times?) times,
    ].join(' · ');

    return FinalScoreBlock(
      score: _viewModel.score,
      approved: _viewModel.isApproved,
      details: [detail],
    );
  }

  /// O estado do envio da avaliação deste aparelho e o aviso sobre de onde
  /// vieram os dados — os dois só aparecem quando há o que dizer.
  List<Widget> _buildNotices() {
    final send = _viewModel.sendNotice;
    final data = _viewModel.dataNotice;
    final notices = <Widget>[
      if (send != null) _sendNotice(send, _viewModel.sendStatus),
      if (data != null) _dataNotice(data),
      if (_viewModel.canRetry)
        AppSecondaryButton(
          label: 'Tentar novamente',
          icon: AppIcons.retry,
          onPressed: _viewModel.retry,
        ),
    ];

    return [
      for (final notice in notices)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
          child: notice,
        ),
    ];
  }

  Widget _sendNotice(String message, LocalSyncStatus? status) {
    final (icon, tone) = switch (status) {
      LocalSyncStatus.error => (AppIcons.sendFailed, NoticeTone.danger),
      LocalSyncStatus.synced => (AppIcons.syncDone, NoticeTone.success),
      _ => (AppIcons.pending, NoticeTone.neutral),
    };
    return InlineNotice(icon: icon, tone: tone, message: message);
  }

  Widget _dataNotice(ResultDataNotice notice) {
    final (icon, tone, message) = switch (notice) {
      ResultDataNotice.deviceFallback => (
          AppIcons.offline,
          NoticeTone.neutral,
          'Mostrando a avaliação feita neste aparelho.',
        ),
      ResultDataNotice.offline => (
          AppIcons.offline,
          NoticeTone.warning,
          'Sem conexão: as infrações aparecem quando houver internet.',
        ),
      ResultDataNotice.serverFailed => (
          AppIcons.needsReview,
          NoticeTone.danger,
          'Não foi possível carregar as infrações.',
        ),
      ResultDataNotice.notOnServer => (
          AppIcons.needsReview,
          NoticeTone.neutral,
          'Não há avaliação registrada no servidor para este participante.',
        ),
    };
    return InlineNotice(icon: icon, tone: tone, message: message);
  }

  Widget _buildSectionHeader(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.sectionTitle)),
          if (trailing != null) Text(trailing, style: AppTypography.categoryCount),
        ],
      ),
    );
  }

  /// "Desempenho por categoria": o código, o nome, quantas infrações e o
  /// selo de % — no lugar dos pontos do canvas, que o app não tem.
  Widget _buildPerformance(List<ResultCategory> categories) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xs),
      child: Column(
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xl),
            _buildPerformanceRow(categories[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(ResultCategory category) {
    return Row(
      key: ValueKey('result-performance-${category.id}'),
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
        Text(infractionCountLabel(category.infractions.length), style: AppTypography.categoryCount),
        const SizedBox(width: AppSpacing.sm + 2),
        ScoreBadge(score: category.score!),
      ],
    );
  }

  List<Widget> _buildInfractions(List<ResultCategory> categories) {
    if (_viewModel.infractionCount == 0) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
          child: Text('Nenhuma infração registrada.', style: AppTypography.body),
        ),
      ];
    }

    final open = _open ??= {
      if (categories.where((c) => c.infractions.isNotEmpty).firstOrNull case final first?)
        first.id,
    };

    return [
      for (final category in categories) ...[
        _buildGroupHeader(category, open.contains(category.id)),
        if (open.contains(category.id))
          for (final infraction in category.infractions) _buildInfraction(infraction),
      ],
      _buildFootnote(),
    ];
  }

  /// Cabeçalho de um grupo de "Infrações registradas": abre e fecha o grupo.
  /// Sem infração na categoria, não há o que abrir.
  ///
  /// O fundo fica num `Material` próprio, embaixo do `InkWell`: como cor do
  /// `Container` de dentro, ele cobria o efeito de toque.
  Widget _buildGroupHeader(ResultCategory category, bool isOpen) {
    final hasInfractions = category.infractions.isNotEmpty;

    return Material(
      color: isOpen ? AppColors.categoryExpandedBg : AppColors.surface,
      child: InkWell(
        key: ValueKey('result-group-${category.id}'),
        onTap: hasInfractions
            ? () => setState(() {
                  final open = _open!;
                  if (!open.remove(category.id)) open.add(category.id);
                })
            : null,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: const BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: AppColors.categoryExpandedBorder),
            ),
          ),
          child: Row(
            children: [
              CategoryCodeChip(
                code: category.code,
                background: isOpen ? AppColors.primary : AppColors.categoryChipBg,
                ink: isOpen ? AppColors.surface : AppColors.primaryDark,
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
              Text(
                infractionCountLabel(category.infractions.length),
                style: AppTypography.categoryCount,
              ),
              if (hasInfractions) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  isOpen ? AppIcons.expandLess : AppIcons.expandMore,
                  size: 22,
                  color: AppColors.text3,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfraction(ResultInfraction infraction) {
    final comment = infraction.comment;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoteBadge(noteType: infraction.noteType),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // O número é o item na ficha oficial, como no checklist.
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 14),
                      child: Text('${infraction.number}', style: AppTypography.infractionNumber),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(infraction.description, style: AppTypography.infractionDescription),
                    ),
                  ],
                ),
                if (comment != null) ...[
                  const SizedBox(height: AppSpacing.xs + 1),
                  Text(comment, style: AppTypography.summaryDetail),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFootnote() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md + 2,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Text(
        'O número de cada linha é o item da categoria na ficha oficial — é por '
        'ele que a infração é localizada em caso de contestação.',
        style: AppTypography.meta,
      ),
    );
  }

  /// Um botão no máximo: "Próximo participante" logo depois do "Confirmar",
  /// ou "Reavaliar" para quem está em "Necessita reavaliação". Nos outros
  /// casos, o X fecha a tela.
  Widget? _buildFooter(bool isOffline) {
    if (_viewModel.isLoading) return null;

    final Widget content;
    if (_viewModel.justConfirmed) {
      content = AppCtaButton(
        label: 'Próximo participante',
        trailingIcon: AppIcons.chevronRight,
        size: AppCtaSize.large,
        // Volta ao detalhe da sessão, onde o consultor escolhe quem avaliar
        // em seguida (decisão de 01/10/2026).
        onPressed: () => Navigator.of(context).maybePop(),
      );
    } else if (_viewModel.canReevaluate) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCtaButton(
            label: 'Reavaliar',
            icon: AppIcons.retry,
            size: AppCtaSize.large,
            // O "Iniciar avaliação" do checklist é que reserva o participante,
            // e isso precisa de rede: sem ela, nem vale abrir o checklist.
            onPressed: isOffline ? null : _reevaluate,
          ),
          if (isOffline) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Text(
              'Disponível quando houver conexão',
              style: AppTypography.meta,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      );
    } else {
      return null;
    }

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
      child: content,
    );
  }

  /// "Reavaliar": troca o Resultado pelo checklist em "não iniciada", sem
  /// reservar nada — o participante só muda de status no "Iniciar avaliação"
  /// de lá (decisão de 06/10/2026). O voltar do checklist leva ao detalhe da
  /// sessão.
  void _reevaluate() {
    context.pushReplacement(
      AppRoutes.participantChecklist(widget.sessionId, widget.participantId),
    );
  }
}

/// A nota da infração ("PM") na cor cheia dela — o selo das linhas de
/// "Infrações registradas" (canvas "2g").
class _NoteBadge extends StatelessWidget {
  const _NoteBadge({required this.noteType});

  final String noteType;

  Color get _fill => switch (noteType) {
        'B' => AppColors.noteBFill,
        'PM' => AppColors.notePmFill,
        _ => AppColors.noteMFill,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: AppSpacing.xxl + 1,
        minHeight: AppSpacing.xl,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(noteType, style: AppTypography.resultNoteBadge),
    );
  }
}
