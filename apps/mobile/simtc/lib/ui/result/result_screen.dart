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
import '../core/form_factor.dart';
import '../core/open_once.dart';
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
  /// O painel da nota no tablet em paisagem (quadro "4i").
  static const double summaryPaneWidth = 452;

  /// Altura mínima do cabeçalho de grupo de "Infrações registradas" no
  /// tablet.
  static const double groupMinHeightTablet = 56;

  /// O selo da nota da infração no tablet: 34×26.
  static const Size noteBadgeSizeTablet = Size(34, 26);

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

  /// Recuo das laterais: 20 no celular, 24 no tablet.
  double get _inset => context.isTablet ? AppSpacing.xxl : AppSpacing.xl;

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;
    final expanded = context.isExpandedLayout && !_viewModel.isLoading;
    final footer = expanded ? null : _buildFooter(isOffline);

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
            Expanded(child: expanded ? _buildTwoPanes(isOffline) : _buildBody()),
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

    return ListView(
      children: [..._buildSummaryPart(), ..._buildInfractionsPart(divider: context.isTablet)],
    );
  }

  /// Tablet em paisagem (quadro "4i"): à esquerda, num painel de 452, a nota,
  /// os avisos, o desempenho e o botão embaixo; à direita, as infrações.
  Widget _buildTwoPanes(bool isOffline) {
    final actions = _buildFooterContent(isOffline);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const Key('result-summary-pane'),
          width: summaryPaneWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: ListView(children: _buildSummaryPart())),
              if (actions != null)
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                  ),
                  child: actions,
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
        Expanded(
          child: ListView(
            key: const Key('result-infractions-pane'),
            children: _buildInfractionsPart(divider: false),
          ),
        ),
      ],
    );
  }

  /// A nota, os avisos e o desempenho por categoria.
  List<Widget> _buildSummaryPart() {
    final withScore = [
      for (final category in _viewModel.categories ?? const <ResultCategory>[])
        if (category.score != null) category,
    ];

    return [
      _buildScore(),
      ..._buildNotices(),
      if (withScore.isNotEmpty) ...[
        _buildSectionHeader(
          'Desempenho por categoria',
          bottom: context.isTablet ? AppSpacing.lg : AppSpacing.sm + 2,
        ),
        _buildPerformance(withScore),
      ],
    ];
  }

  /// "Infrações registradas". Com [divider], uma linha em cima e 20 de
  /// recuo — o tablet em retrato (quadro "4t").
  List<Widget> _buildInfractionsPart({required bool divider}) {
    final categories = _viewModel.categories;
    if (categories == null) return const [];
    final count = _viewModel.infractionCount;
    final header = _buildSectionHeader(
      'Infrações registradas',
      trailing: count == 0 ? null : infractionCountLabel(count),
      top: divider ? AppSpacing.xl : AppSpacing.lg,
    );

    return [
      if (divider)
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: header,
        )
      else
        header,
      ..._buildInfractions(categories),
    ];
  }

  /// "Ana Paula Ribeiro · 042.118.***-** · Início 08:12 · Fim 08:31".
  Widget _buildScore() {
    final participant = _viewModel.participant;
    final detail = [
      if (participant != null && participant.name.isNotEmpty) participant.name,
      if (participant != null) participant.maskedCpf,
      if (_viewModel.timesLabel case final times?) times,
    ].join(' · ');
    final tablet = context.isTablet;

    return FinalScoreBlock(
      score: _viewModel.score,
      approved: _viewModel.isApproved,
      details: [detail],
      scale: tablet ? FinalScoreScale.resultTablet : FinalScoreScale.phone,
      padding: EdgeInsets.all(_inset),
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
          padding: EdgeInsets.fromLTRB(_inset, AppSpacing.lg, _inset, 0),
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

  Widget _buildSectionHeader(
    String title, {
    String? trailing,
    double top = AppSpacing.lg,
    double bottom = AppSpacing.sm + 2,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(_inset, top, _inset, bottom),
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
  /// No tablet (quadros "4i" e "4t"), 25 entre as linhas e 20 embaixo.
  Widget _buildPerformance(List<ResultCategory> categories) {
    final tablet = context.isTablet;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _inset,
        AppSpacing.xs,
        _inset,
        tablet ? AppSpacing.xl : AppSpacing.xs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) SizedBox(height: tablet ? AppSpacing.xxl + 1 : AppSpacing.xl),
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
            style: context.isTablet
                ? AppTypography.resultPerformanceNameTablet
                : AppTypography.categoryName,
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
          padding: EdgeInsets.fromLTRB(_inset, 0, _inset, _inset),
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
    ];
  }

  /// Cabeçalho de um grupo de "Infrações registradas": abre e fecha o grupo.
  /// Sem infração na categoria, não há o que abrir.
  ///
  /// O fundo fica num `Material` próprio, embaixo do `InkWell`: como cor do
  /// `Container` de dentro, ele cobria o efeito de toque.
  ///
  /// No tablet (quadros "4i" e "4t"): 16 em cima e embaixo, 24 dos lados,
  /// 56 de altura mínima, nome de 15,5 e vão de 12.
  Widget _buildGroupHeader(ResultCategory category, bool isOpen) {
    final hasInfractions = category.infractions.isNotEmpty;
    final tablet = context.isTablet;
    final double gap = tablet ? AppSpacing.md : AppSpacing.sm + 2;

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
          constraints: BoxConstraints(minHeight: tablet ? groupMinHeightTablet : 0),
          padding: tablet
              ? const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg)
              : const EdgeInsets.all(AppSpacing.xl),
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
              SizedBox(width: gap),
              Expanded(
                child: Text(
                  category.name,
                  style: tablet
                      ? AppTypography.resultGroupNameTablet
                      : AppTypography.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: gap),
              Text(
                infractionCountLabel(category.infractions.length),
                style: tablet
                    ? AppTypography.resultGroupCountTablet
                    : AppTypography.categoryCount,
              ),
              if (hasInfractions) ...[
                SizedBox(width: tablet ? gap : AppSpacing.sm),
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

  /// No tablet (quadros "4i" e "4t"): 16 em cima e embaixo, 24 dos lados, o
  /// selo de 34×26 e a descrição de 15,5, centrados na linha.
  Widget _buildInfraction(ResultInfraction infraction) {
    final comment = infraction.comment;
    final tablet = context.isTablet;

    return Container(
      padding: tablet
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg)
          : const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
      ),
      child: Row(
        crossAxisAlignment: tablet ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          _NoteBadge(noteType: infraction.noteType, large: tablet),
          SizedBox(width: tablet ? AppSpacing.md + 2 : AppSpacing.md),
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
                      child: Text(
                        infraction.description,
                        style: tablet
                            ? AppTypography.resultInfractionTablet
                            : AppTypography.infractionDescription,
                      ),
                    ),
                  ],
                ),
                if (comment != null) ...[
                  SizedBox(height: tablet ? AppSpacing.xs : AppSpacing.xs + 1),
                  Text(comment, style: AppTypography.summaryDetail),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Um botão no máximo: "Próximo participante" logo depois do "Confirmar",
  /// ou "Reavaliar" para quem está em "Não recomendado". Nos outros
  /// casos, o X fecha a tela.
  Widget? _buildFooter(bool isOffline) {
    final content = _buildFooterContent(isOffline);
    if (content == null) return null;
    final tablet = context.isTablet;

    // No tablet em retrato, 16 em cima e embaixo e 24 dos lados (quadro "4t").
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: tablet
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg)
          : const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
      child: content,
    );
  }

  Widget? _buildFooterContent(bool isOffline) {
    if (_viewModel.isLoading) return null;

    final size = context.isTablet ? AppCtaSize.tabletLarge : AppCtaSize.large;
    final Widget content;
    if (_viewModel.justConfirmed) {
      content = AppCtaButton(
        label: 'Próximo participante',
        trailingIcon: AppIcons.chevronRight,
        size: size,
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
            size: size,
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
    return content;
  }

  /// "Reavaliar": abre o checklist em "não iniciada" por cima do Resultado,
  /// sem reservar nada — o participante só muda de status no "Iniciar
  /// avaliação" de lá, e o voltar do checklist traz de volta a este
  /// Resultado (decisões de 06/10/2026).
  void _reevaluate() {
    if (!context.claimOpen()) return;
    context.push(
      AppRoutes.participantChecklist(
        widget.sessionId,
        widget.participantId,
        fromResult: true,
      ),
    );
  }
}

/// A nota da infração ("PM") na cor cheia dela — o selo das linhas de
/// "Infrações registradas" (canvas "2g").
class _NoteBadge extends StatelessWidget {
  const _NoteBadge({required this.noteType, this.large = false});

  final String noteType;

  /// O selo do tablet (quadros "4i" e "4t"): 34×26, canto 6, nota de 12.
  final bool large;

  Color get _fill => switch (noteType) {
        'B' => AppColors.noteBFill,
        'PM' => AppColors.notePmFill,
        _ => AppColors.noteMFill,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: large
          ? BoxConstraints.tight(_ResultScreenState.noteBadgeSizeTablet)
          : const BoxConstraints(
              minWidth: AppSpacing.xxl + 1,
              minHeight: AppSpacing.xl,
            ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(
        noteType,
        style: large ? AppTypography.resultNoteBadgeTablet : AppTypography.resultNoteBadge,
      ),
    );
  }
}
