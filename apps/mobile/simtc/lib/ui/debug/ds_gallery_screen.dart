import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_checkbox.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/filter_chip_bar.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/pill_nav_bar.dart';
import '../core/widgets/session_card.dart';
import '../core/widgets/severity_badge.dart';
import '../core/widgets/skeleton.dart';
import '../core/widgets/status_chip.dart';

/// Galeria dos componentes do Design System, acessível só em build de debug
/// (rota `/ds`). Serve para conferir cor, espaçamento e toque no aparelho real,
/// sem depender de uma tela de produção estar pronta.
class DsGalleryScreen extends StatefulWidget {
  const DsGalleryScreen({super.key});

  @override
  State<DsGalleryScreen> createState() => _DsGalleryScreenState();
}

class _DsGalleryScreenState extends State<DsGalleryScreen> {
  final TextEditingController _textController =
      TextEditingController(text: 'carla.mendes@simtc.com.br');
  final TextEditingController _passwordController =
      TextEditingController(text: 'segredo123');
  bool _obscure = true;
  bool _checked = true;
  int _filterIndex = 0;
  int _navIndex = 0;

  @override
  void dispose() {
    _textController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design System')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              120,
            ),
            children: [
              _buildSection('Formulário', _buildFormSamples()),
              _buildSection('Status e severidade', _buildChipSamples()),
              _buildSection('Filtros', _buildFilterSample()),
              _buildSection('Sessão', _buildSessionSamples()),
              _buildSection('Carregamento', const SkeletonListItem()),
              _buildSection(
                'Conectividade',
                const ConnectivityBanner(isOffline: true),
              ),
            ],
          ),
          Align(alignment: Alignment.bottomCenter, child: _buildNavBar()),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.screenTitle),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }

  Widget _buildFormSamples() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'E-mail',
          controller: _textController,
          icon: AppIcons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Senha',
          controller: _passwordController,
          icon: AppIcons.password,
          obscureText: _obscure,
          onToggleObscure: () => setState(() => _obscure = !_obscure),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Campo com erro',
          controller: _textController,
          icon: AppIcons.email,
          errorText: 'E-mail ou senha incorretos',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCheckbox(
          value: _checked,
          label: 'Manter conectado',
          onChanged: (v) => setState(() => _checked = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(label: 'Entrar', onPressed: () {}),
        const SizedBox(height: AppSpacing.md),
        const AppPrimaryButton(label: 'Entrando', isLoading: true),
        const SizedBox(height: AppSpacing.md),
        const AppPrimaryButton(label: 'Sem ação'),
        const SizedBox(height: AppSpacing.md),
        AppSecondaryButton(label: 'Cancelar', onPressed: () {}),
        const SizedBox(height: AppSpacing.lg),
        const InlineNotice(
          icon: AppIcons.noSignal,
          message: 'Sem sinal: as ações administrativas ficam indisponíveis.',
          tone: NoticeTone.warning,
        ),
      ],
    );
  }

  Widget _buildChipSamples() {
    return const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        StatusChip(label: 'Pendente', icon: AppIcons.pending, tone: StatusTone.neutral),
        StatusChip(label: 'Em avaliação', icon: AppIcons.inProgress, tone: StatusTone.warning),
        StatusChip(label: 'Aprovado', icon: AppIcons.approved, tone: StatusTone.success),
        StatusChip(label: 'Reavaliar', icon: AppIcons.needsReview, tone: StatusTone.danger),
        StatusChip(label: 'Somente teórica', icon: AppIcons.theoryOnly, tone: StatusTone.mauve),
        StatusChip(label: 'Em andamento', icon: AppIcons.sessions, tone: StatusTone.info),
        SeverityBadge(severity: Severity.b),
        SeverityBadge(severity: Severity.pm),
        SeverityBadge(severity: Severity.m),
      ],
    );
  }

  Widget _buildFilterSample() {
    return FilterChipBar(
      selectedIndex: _filterIndex,
      onSelect: (i) => setState(() => _filterIndex = i),
      items: const [
        FilterChipData(label: 'Hoje', count: 2),
        FilterChipData(label: 'Semana', count: 5),
        FilterChipData(label: 'Concluídas', count: 12),
      ],
    );
  }

  Widget _buildSessionSamples() {
    return Column(
      children: [
        SessionCard(
          companyName: 'Bracell Celulose',
          courseName: 'Direção Preventiva — Leve',
          meta: 'Hoje · 08:00 · Lençóis Paulista/SP',
          accentColor: AppColors.warningBorder,
          statusChip: const StatusChip(
            label: 'Em andamento',
            icon: AppIcons.inProgress,
            tone: StatusTone.warning,
          ),
          progressLabel: '4 de 12 avaliados',
          progressValue: 4 / 12,
          onTap: () {},
        ),
        SessionCard(
          companyName: 'Mineração Serra Azul',
          courseName: 'Direção Preventiva — Pesado',
          meta: '15 set · 13:30 · Itabira/MG',
          statusChip: const StatusChip(
            label: 'Planejado',
            icon: AppIcons.sessions,
            tone: StatusTone.info,
          ),
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildNavBar() {
    return PillNavBar(
      currentIndex: _navIndex,
      onSelect: (i) => setState(() => _navIndex = i),
      items: const [
        PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
        PillNavItem(icon: AppIcons.sync, label: 'Sincronizar', badgeCount: 3),
        PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
      ],
    );
  }
}
