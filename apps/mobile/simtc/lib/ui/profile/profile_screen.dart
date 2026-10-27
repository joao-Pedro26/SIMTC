import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/auth_user.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/assessment_sync_service.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/device_data_service.dart';
import '../../router.dart';
import '../core/form_factor.dart';
import '../core/open_once.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_nav_bar.dart';
import 'profile_labels.dart';
import 'profile_viewmodel.dart';

/// Tela 1.10 — aba "Perfil" (quadros "2i" do celular e "4k"/"4v" do tablet,
/// Fase 8A).
///
/// Quem entrou, o perfil de acesso, a última sincronização, o "Limpar cache
/// local" e a versão do app; e o "Sair da conta", que pede confirmação. Sem a
/// linha "Empresa" do canvas: o backend não liga consultor a nenhuma empresa
/// (decisão de 24/10/2026).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.clock});

  /// Relógio injetável para os testes; o padrão é `DateTime.now`.
  final DateTime Function()? clock;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileViewModel _viewModel = ProfileViewModel(
    auth: context.read<AuthRepository>(),
    assessments: context.read<AssessmentRepository>(),
    deviceData: context.read<DeviceDataService>(),
  )..init();

  /// O texto do rodapé do canvas mandava sincronizar antes de sair; com a
  /// fila guardada no "Sair" (decisão de 24/10/2026), ele diz isso.
  static const String _footnote =
      'Sair apaga as sessões baixadas neste aparelho. As avaliações na fila '
      'ficam guardadas e são enviadas quando você entrar de novo.';

  static const String _clearMessage =
      'As sessões, os participantes, o catálogo e os logos baixados serão '
      'apagados e baixados de novo quando você abrir as sessões. A fila e as '
      'avaliações iniciadas não são apagadas.';

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<AssessmentSyncService>();
    final isOffline = context.watch<ConnectivityService>().isOffline;
    final now = (widget.clock ?? DateTime.now)();
    final tablet = context.isTablet;
    final content = Column(
      children: [
        _buildHeader(tablet: tablet),
        Expanded(
          child: ListenableBuilder(
            listenable: _viewModel,
            builder: (context, _) => tablet
                ? _buildTabletBody(sync, isOffline, now)
                : _buildBody(sync, isOffline, now),
          ),
        ),
      ],
    );

    // É uma aba, não uma tela empilhada: o voltar do Android leva para
    // Sessões, em vez de fechar o app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: TabSnackBarArea(
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: tablet
                ? TabletNavFrame(current: AppTab.profile, child: content)
                : content,
          ),
          bottomNavigationBar:
              tablet ? null : const AppNavBar(current: AppTab.profile),
        ),
      ),
    );
  }

  /// Tablet: 14 em cima e embaixo, 24 dos lados e título de 24 (quadros
  /// "4k" e "4v").
  Widget _buildHeader({required bool tablet}) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: tablet
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.md + 2,
            )
          : const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm + 2,
            ),
      child: Text(
        'Perfil',
        style: tablet ? AppTypography.homeTitle : AppTypography.screenTitle,
      ),
    );
  }

  /// No tablet, uma coluna de no máximo 820, centrada, com 24 de margem
  /// pelo menos (quadros "4k" e "4v").
  static const double _tabletColumnWidth = 820;

  Widget _buildTabletBody(
    AssessmentSyncService sync,
    bool isOffline,
    DateTime now,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(
          AppSpacing.xxl,
          (constraints.maxWidth - _tabletColumnWidth) / 2,
        );
        return ListView(
          padding: EdgeInsets.fromLTRB(
            side,
            AppSpacing.xxl,
            side,
            AppSpacing.xxxl,
          ),
          children: [
            _buildTabletIdentity(_viewModel.user, isOffline),
            _buildRows(sync, isOffline, now, tablet: true),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Text(_footnote, style: AppTypography.profileNoteTablet),
            ),
          ],
        );
      },
    );
  }

  /// Tablet: o nome e o e-mail à esquerda, o "Sair da conta" à direita, 16
  /// entre os dois e 22 até as linhas.
  Widget _buildTabletIdentity(AuthUser? user, bool isOffline) {
    return Padding(
      key: const Key('profile-identity'),
      padding: const EdgeInsets.only(bottom: AppSpacing.xl + 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.name ?? '', style: AppTypography.profileNameTablet),
                const SizedBox(height: AppSpacing.xs + 1),
                Text(
                  user?.email ?? '',
                  style: AppTypography.profileEmailTablet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          _buildLogoutButton(isOffline, compact: true),
        ],
      ),
    );
  }

  Widget _buildBody(AssessmentSyncService sync, bool isOffline, DateTime now) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.xxl),
      children: [
        _buildIdentity(_viewModel.user),
        _buildRows(sync, isOffline, now),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
            0,
          ),
          child: _buildLogoutButton(isOffline),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            0,
          ),
          child: Text(_footnote, style: AppTypography.profileNote),
        ),
      ],
    );
  }

  /// Nome e e-mail: 20 de recuo, 4 entre os dois e 20 até as linhas.
  Widget _buildIdentity(AuthUser? user) {
    return Padding(
      key: const Key('profile-identity'),
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user?.name ?? '', style: AppTypography.detailTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            user?.email ?? '',
            style: AppTypography.profileEmail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// As quatro linhas, coladas: uma divisória de 1,5 em cima do grupo e uma
  /// embaixo de cada linha (o quadro desenha em cima e embaixo de cada uma,
  /// o que somaria 3 entre duas).
  Widget _buildRows(
    AssessmentSyncService sync,
    bool isOffline,
    DateTime now, {
    bool tablet = false,
  }) {
    final user = _viewModel.user;
    final bytes = _viewModel.cacheBytes;
    final busy = _viewModel.isClearing || _viewModel.isLoggingOut;

    // Um `Container`, e não um `DecoratedBox`: a divisória de cima ocupa o
    // seu 1,5 em vez de ser pintada por cima da primeira linha.
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileRow(
            key: const Key('profile-row-role'),
            tablet: tablet,
            icon: AppIcons.accessRole,
            label: 'Perfil de acesso',
            value: user == null ? '' : roleLabel(user.role),
          ),
          _ProfileRow(
            key: const Key('profile-row-sync'),
            tablet: tablet,
            icon: AppIcons.sync,
            label: 'Última sincronização',
            value: lastSyncValue(sync.lastSyncedAt, now),
          ),
          _ProfileRow(
            key: const Key('profile-row-cache'),
            tablet: tablet,
            icon: AppIcons.clearCache,
            label: 'Limpar cache local',
            note: isOffline ? 'Disponível quando houver conexão' : null,
            value: bytes == null ? '—' : sizeLabel(bytes),
            isLoading: _viewModel.isClearing,
            onTap: isOffline || busy ? null : _confirmClear,
          ),
          _ProfileRow(
            key: const Key('profile-row-version'),
            tablet: tablet,
            icon: AppIcons.info,
            label: 'Versão do app',
            value: _viewModel.version ?? '—',
            valueColor: AppColors.text3,
          ),
        ],
      ),
    );
  }

  /// No tablet, [compact]: o botão de 48 ao lado do nome, da largura do
  /// rótulo (quadros "4k" e "4v").
  Widget _buildLogoutButton(bool isOffline, {bool compact = false}) {
    return AppDangerOutlineButton(
      label: 'Sair da conta',
      icon: AppIcons.logout,
      compact: compact,
      expand: !compact,
      isLoading: _viewModel.isLoggingOut,
      onPressed: _viewModel.isClearing ? null : () => _confirmLogout(isOffline),
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar cache local?'),
        content: const Text(_clearMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final cleared = await _viewModel.clearCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cleared
              ? 'Cache local limpo.'
              : 'Não foi possível limpar o cache. Tente de novo.',
        ),
      ),
    );
  }

  /// Avisa e deixa sair (decisão de 24/10/2026): a confirmação diz o que fica
  /// guardado no aparelho e, sem rede, que entrar de novo vai exigir conexão.
  Future<void> _confirmLogout(bool isOffline) async {
    final queued = context.read<AssessmentSyncService>().queue.length;
    final drafts = await _viewModel.countStartedDrafts();
    // A confirmação só abre depois de contar as avaliações iniciadas: o
    // segundo de dois toques rápidos conta de novo, mas não abre outra
    // (Fase 8C).
    if (!mounted || !context.claimOpen()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: Text(
          logoutMessage(queued: queued, drafts: drafts, offline: isOffline),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Saindo, o roteador leva ao login sozinho; aqui só a falha importa.
    final left = await _viewModel.logout();
    if (left || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível sair. Tente de novo.')),
    );
  }
}

/// Uma linha do Perfil (quadro "2i"): ícone de 22, rótulo e valor; 15 em
/// cima e embaixo, 20 dos lados, 14 entre o ícone e o rótulo, e pelo menos
/// 56 de altura. No [tablet] (quadros "4k" e "4v"): ícone de 23, 18 em cima e
/// embaixo, sem recuo dos lados (a coluna já tem), 16 entre o ícone e o
/// rótulo e pelo menos 64. Com [onTap], a linha inteira é o alvo do toque;
/// [note] aparece embaixo do rótulo (o motivo de estar desativada).
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    super.key,
    this.tablet = false,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.note,
    this.isLoading = false,
    this.onTap,
  });

  final bool tablet;
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final String? note;
  final bool isLoading;
  final VoidCallback? onTap;

  static const double _iconSize = 22;
  static const double _iconGap = AppSpacing.md + 2;
  static const double _tabletIconSize = 23;
  static const double _tabletMinHeight = AppSpacing.controlHeight + AppSpacing.sm;
  static const double _spinnerSize = 16;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            minHeight: tablet ? _tabletMinHeight : AppSpacing.controlHeight,
          ),
          padding: tablet
              ? const EdgeInsets.symmetric(vertical: AppSpacing.lg + 2)
              : const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md + 3,
                ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: tablet ? _tabletIconSize : _iconSize,
                color: AppColors.text3,
              ),
              SizedBox(width: tablet ? AppSpacing.lg : _iconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: tablet
                          ? AppTypography.profileRowLabelTablet
                          : AppTypography.profileRowLabel,
                    ),
                    if (note != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(note, style: AppTypography.meta),
                    ],
                  ],
                ),
              ),
              // 14 no celular ("2i") e 16 no tablet ("4k"/"4v") (Fase 8C).
              SizedBox(width: tablet ? AppSpacing.lg : AppSpacing.md + 2),
              if (isLoading)
                const SizedBox(
                  width: _spinnerSize,
                  height: _spinnerSize,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  value,
                  style: (tablet
                          ? AppTypography.profileRowValueTablet
                          : AppTypography.profileRowValue)
                      .copyWith(color: valueColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
