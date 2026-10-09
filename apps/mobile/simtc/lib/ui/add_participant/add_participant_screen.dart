import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../core/cpf_input_formatter.dart';
import '../core/date_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/session_context_header.dart';
import '../core/widgets/skeleton.dart';
import '../core/widgets/sync_status_indicator.dart';
import 'add_participant_viewmodel.dart';

/// Tela 1.11 — "Adicionar participante" (quadro "3a" do canvas), só para
/// ADMIN.
///
/// Diferenças do canvas, aprovadas em 06/10/2026: o CPF vem antes do nome
/// (ele é consultado no servidor, que preenche o resto para quem já tem
/// cadastro), não há "Consultor responsável" (o participante entra pendente;
/// atribuir a outro consultor não existe no backend) e os avisos da consulta
/// são novos.
class AddParticipantScreen extends StatefulWidget {
  const AddParticipantScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<AddParticipantScreen> createState() => _AddParticipantScreenState();
}

class _AddParticipantScreenState extends State<AddParticipantScreen> {
  late final AddParticipantViewModel _viewModel = AddParticipantViewModel(
    sessionId: widget.sessionId,
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    currentUser: context.read<AuthRepository>().currentUser,
  )..init();

  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _cpfFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_syncFields);
    _emailFocus.addListener(_onEmailFocusChange);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_syncFields);
    _emailFocus.removeListener(_onEmailFocusChange);
    _viewModel.dispose();
    _cpfController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _cpfFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  /// Leva para os campos o que a ViewModel mudou sozinha: o preenchimento
  /// pelo cadastro, a limpeza ao trocar o CPF e o formulário zerado do
  /// "Salvar e adicionar outro". O que o admin digita já chega igual, e aí
  /// nada é reescrito (o cursor fica onde está).
  void _syncFields() {
    if (_nameController.text != _viewModel.name) {
      _nameController.text = _viewModel.name;
    }
    if (_emailController.text != _viewModel.email) {
      _emailController.text = _viewModel.email;
    }
    if (_viewModel.cpf.isEmpty && _cpfController.text.isNotEmpty) {
      _cpfController.clear();
    }
  }

  /// O erro do e-mail só aparece depois que o admin sai do campo — no meio
  /// da digitação, todo e-mail está "errado".
  void _onEmailFocusChange() => setState(() {});

  bool get _fieldsEnabled => _viewModel.canAdd && !_viewModel.isSubmitting;

  bool get _showEmailError => !_emailFocus.hasFocus && !_viewModel.isEmailValid;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;
    // O teclado aberto tira espaço do rodapé: ver `_buildFooter`.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    // Todo fechar passa por `_close`: ele confirma o descarte e devolve à
    // tela de baixo se alguém foi adicionado.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              // Sem toque: abrir a aba Sincronizar daqui largaria o formulário.
              const AppTopBar(
                title: 'Adicionar participante',
                leadingIcon: AppIcons.close,
                leadingIconSize: 26,
                leadingTooltip: 'Fechar',
                trailing: SyncStatusIndicator(),
              ),
              ConnectivityBanner(
                isOffline: isOffline,
                message: 'Sem conexão — adicionar participante precisa de internet.',
              ),
              Expanded(child: _buildBody()),
              if (_viewModel.session != null)
                _buildFooter(isOffline, keyboardOpen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) return _buildSkeleton();

    final session = _viewModel.session;
    final lockedReason = _viewModel.lockedReason;
    if (session == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: InlineNotice(icon: AppIcons.sessions, message: lockedReason ?? ''),
      );
    }

    final registryNotice = _viewModel.registryNotice;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        SessionContextHeader(
          companyName: session.companyName,
          logoUrl: session.companyLogoUrl,
          subtitle: _contextLine(session),
          muted: true,
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lockedReason != null) ...[
                InlineNotice(icon: AppIcons.lockedByOther, message: lockedReason),
                const SizedBox(height: AppSpacing.lg + 2),
              ],
              _buildCpfField(),
              if (registryNotice != null) ...[
                const SizedBox(height: AppSpacing.md),
                InlineNotice(icon: AppIcons.profile, message: registryNotice),
              ],
              const SizedBox(height: AppSpacing.lg + 2),
              _buildNameField(),
              const SizedBox(height: AppSpacing.lg + 2),
              _buildEmailField(),
              const SizedBox(height: AppSpacing.lg + 2),
              _buildTypeSelector(),
            ],
          ),
        ),
      ],
    );
  }

  /// "Direção Defensiva — Veículo Pesado · 12 set": o admin cadastra em
  /// sequência e precisa saber em que sessão está.
  String _contextLine(TrainingSession session) {
    final date = session.date;
    return date == null
        ? session.courseName
        : '${session.courseName} · ${dayMonthLabel(date)}';
  }

  /// Primeiro campo, e sem máscara de privacidade: é o admin digitando, não
  /// a tela que passa pela mão do participante (canvas "3a").
  Widget _buildCpfField() {
    return AppTextField(
      key: const Key('campo-cpf'),
      label: 'CPF',
      controller: _cpfController,
      focusNode: _cpfFocus,
      icon: AppIcons.cpf,
      hintText: '000.000.000-00',
      mono: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: const [CpfInputFormatter()],
      enabled: _fieldsEnabled,
      errorText: _viewModel.cpfError,
      helperText: _viewModel.cpfHelper,
      trailing: _buildCpfTrailing(),
      onChanged: _viewModel.setCpf,
    );
  }

  Widget? _buildCpfTrailing() {
    return switch (_viewModel.cpfCheck) {
      CpfCheck.checking => const SizedBox.square(
          dimension: AppSpacing.lg + 2,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      CpfCheck.available =>
        const Icon(AppIcons.approved, size: 20, color: AppColors.savedInk),
      _ => null,
    };
  }

  Widget _buildNameField() {
    return AppTextField(
      key: const Key('campo-nome'),
      label: 'Nome completo',
      controller: _nameController,
      icon: AppIcons.profile,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      enabled: _fieldsEnabled,
      onChanged: _viewModel.setName,
    );
  }

  Widget _buildEmailField() {
    return AppTextField(
      key: const Key('campo-email'),
      label: 'E-mail',
      labelTrailing: 'opcional',
      controller: _emailController,
      focusNode: _emailFocus,
      icon: AppIcons.email,
      hintText: 'para enviar o certificado',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      enabled: _fieldsEnabled,
      errorText: _showEmailError ? 'E-mail inválido.' : null,
      onChanged: _viewModel.setEmail,
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tipo de participação', style: AppTypography.fieldLabel),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildTypeOption(
                type: ParticipationType.teoricaEPratica,
                label: 'Teórica + prática',
                icon: AppIcons.practice,
                iconColor: AppColors.text3,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildTypeOption(
                type: ParticipationType.somenteTeorica,
                label: 'Somente teórica',
                icon: AppIcons.theoryOnly,
                iconColor: AppColors.mauve,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required ParticipationType type,
    required String label,
    required IconData icon,
    required Color iconColor,
  }) {
    final selected = _viewModel.participationType == type;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: Key('tipo-${type.name}'),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: _fieldsEnabled
            ? () => _viewModel.setParticipationType(type)
            : null,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.touchTarget + AppSpacing.lg,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs + 2,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySurface : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderStrong,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.primaryDark : iconColor,
              ),
              const SizedBox(height: AppSpacing.xxs + 1),
              Text(
                label,
                style: selected
                    ? AppTypography.optionCardSelected
                    : AppTypography.optionCard,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A falha do "adicionar" (a rede fora, ou o servidor que recusou) aparece
  /// aqui, acima do botão que o admin acabou de tocar, como no Resumo: dentro
  /// da lista ela podia ficar abaixo da dobra, e a única pista da falha seria o
  /// botão voltar a habilitar. Os avisos do CPF não vêm para cá: ficam sob o
  /// campo.
  ///
  /// Com o teclado aberto, o rodapé fica só com os dois botões: nem o aviso de
  /// falha nem a dica "Disponível quando houver conexão" aparecem. Num celular
  /// baixo com a fonte ampliada, o que sobra acima do teclado não comporta o
  /// aviso, e o rodapé estourava (RenderFlex) até a primeira tecla, que já o
  /// apagava; o teclado só sobe depois da falha porque `_submit` tira o foco
  /// antes de enviar. Fechado o teclado, o aviso e a dica voltam. Os botões não
  /// mudam, nem desabilitados offline: o motivo segue escrito na faixa de
  /// offline do topo.
  Widget _buildFooter(bool isOffline, bool keyboardOpen) {
    final canSubmit = _viewModel.canSubmit && !isOffline;
    final error = _viewModel.errorMessage;

    // Recuos e vão do canvas "3a" (12 em cima, 16 nos lados e embaixo, vão de
    // 8), os mesmos dos rodapés irmãos.
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null && !keyboardOpen) ...[
            InlineNotice(
              icon: AppIcons.needsReview,
              message: error,
              tone: NoticeTone.danger,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppCtaButton(
            label: 'Adicionar participante',
            icon: AppIcons.addParticipant,
            size: AppCtaSize.large,
            isLoading: _viewModel.isSubmitting,
            onPressed: canSubmit ? () => _submit(addAnother: false) : null,
          ),
          if (isOffline && _viewModel.canAdd && !keyboardOpen) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Text(
              'Disponível quando houver conexão',
              style: AppTypography.meta,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppTextButton(
            label: 'Salvar e adicionar outro',
            onPressed: canSubmit ? () => _submit(addAnother: true) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _submit({required bool addAnother}) async {
    FocusScope.of(context).unfocus();
    final added = await _viewModel.submit(addAnother: addAnother);
    if (added == null || !mounted) return;

    // O SnackBar é do `ScaffoldMessenger` do app: continua na tela de baixo.
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (!addAnother) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Participante adicionado.')),
      );
      Navigator.of(context).pop(true);
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('${added.name} entrou na sessão.')),
    );
    // Os campos ficaram travados durante o envio; só aceitam foco no quadro que
    // vem. Pedir o foco agora não faria nada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cpfFocus.requestFocus();
    });
  }

  /// O X, o voltar do Android e o gesto de voltar caem aqui. Com algo
  /// preenchido, pergunta antes; e devolve `true` se alguém entrou na sessão
  /// desde que a tela abriu, para o detalhe se atualizar.
  Future<void> _close() async {
    if (_viewModel.isSubmitting) return;
    if (_viewModel.hasInput && !await _confirmDiscard()) return;
    if (mounted) Navigator.of(context).pop(_viewModel.addedCount > 0);
  }

  Future<bool> _confirmDiscard() async {
    // Com o CPF já inscrito, "ainda não foi adicionado" seria falso: a pessoa
    // está na sessão. Nesse caso o diálogo fica só com o título e os botões.
    final enrolled = _viewModel.cpfCheck == CpfCheck.enrolled;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar o que foi preenchido?'),
        content: enrolled
            ? null
            : const Text('Este participante ainda não foi adicionado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar preenchendo'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Widget _buildSkeleton() {
    return ListView(
      key: const Key('add-participant-skeleton'),
      children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
    );
  }
}
