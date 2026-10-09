import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../router.dart';
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
import 'session_edit_viewmodel.dart';

/// Tela 1.12 — "Dados do treinamento" (quadro "3b" do canvas), só para ADMIN.
///
/// Diferenças do canvas, aprovadas em 06/10/2026: sem "Início" (a sessão não
/// tem horário), "Local" virou "Cidade" + "UF" (é como o backend guarda) e
/// sem o contador das observações (o backend não limita).
class SessionEditScreen extends StatefulWidget {
  const SessionEditScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionEditScreen> createState() => _SessionEditScreenState();
}

class _SessionEditScreenState extends State<SessionEditScreen> {
  late final SessionEditViewModel _viewModel = SessionEditViewModel(
    sessionId: widget.sessionId,
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    currentUser: context.read<AuthRepository>().currentUser,
  )..init();

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  /// Os campos já receberam os valores da sessão — acontece uma vez só, para
  /// uma atualização do cache não apagar o que o admin digitou.
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_fillWhenLoaded);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_fillWhenLoaded);
    _viewModel.dispose();
    _dateController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _fillWhenLoaded() {
    if (_filled || _viewModel.session == null) return;
    _filled = true;

    final date = _viewModel.date;
    _dateController.text = date == null ? '' : dayMonthYearLabel(date);
    _cityController.text = _viewModel.city;
    _stateController.text = _viewModel.state;
    _notesController.text = _viewModel.notes;
  }

  bool get _fieldsEnabled => _viewModel.canEdit && !_viewModel.isBusy;

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

    // O voltar (da barra ou do Android) depende do que está em jogo: com
    // mudança por salvar, pergunta antes; com um envio no ar (salvar ou
    // cancelar), é ignorado — não sai e não pergunta, como o "Descartar" do
    // rodapé, que fica apagado. Sem isso, o diálogo abriria sobre um envio que
    // o servidor ainda vai aceitar, e o `pop(true)` do salvar fecharia o
    // diálogo em vez da tela. O `pop` direto — do "Descartar" e do salvar —
    // não passa por aqui.
    return PopScope<Object?>(
      canPop: !_viewModel.isDirty && !_viewModel.isBusy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_viewModel.isBusy) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              // Sem toque: abrir a aba Sincronizar daqui largaria o formulário.
              const AppTopBar(
                title: 'Dados do treinamento',
                trailing: SyncStatusIndicator(),
              ),
              ConnectivityBanner(
                isOffline: isOffline,
                message: 'Sem conexão — salvar precisa de internet.',
              ),
              Expanded(child: _buildBody(isOffline)),
              if (_viewModel.session != null)
                _buildFooter(isOffline, keyboardOpen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isOffline) {
    if (_viewModel.isLoading) return _buildSkeleton();

    final session = _viewModel.session;
    final lockedReason = _viewModel.lockedReason;
    if (session == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: InlineNotice(icon: AppIcons.sessions, message: lockedReason ?? ''),
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        SessionContextHeader(
          companyName: session.companyName,
          logoUrl: session.companyLogoUrl,
          subtitle: session.courseName,
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
              _buildDateField(),
              const SizedBox(height: AppSpacing.lg + 2),
              _buildPlaceRow(),
              const SizedBox(height: AppSpacing.lg + 2),
              _buildNotesField(),
              // O vão de 18 dos campos mais os 4 do botão: 22, como no quadro
              // "3b" (o gap do bloco e o `padding-top` do botão).
              const SizedBox(height: AppSpacing.lg + 2 + AppSpacing.xs),
              _buildCancelButton(isOffline),
            ],
          ),
        ),
      ],
    );
  }

  /// Não se digita: o toque abre o calendário. Não há "limpar data" — o
  /// backend ignora data vazia.
  Widget _buildDateField() {
    return AppTextField(
      key: const Key('campo-data'),
      label: 'Data',
      controller: _dateController,
      icon: AppIcons.event,
      hintText: 'Sem data',
      readOnly: true,
      enabled: _fieldsEnabled,
      onTap: _pickDate,
    );
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = DateTime(2020);
    final last = DateTime(today.year + 5, 12, 31);
    final current = _viewModel.date ?? today;

    final picked = await showDatePicker(
      context: context,
      // O calendário exige a data inicial dentro do intervalo.
      initialDate: current.isBefore(first)
          ? first
          : current.isAfter(last)
              ? last
              : current,
      firstDate: first,
      lastDate: last,
      helpText: 'Data do treinamento',
    );
    if (picked == null || !mounted) return;

    _viewModel.setDate(picked);
    _dateController.text = dayMonthYearLabel(picked);
  }

  /// Cidade e UF na mesma linha, separadas como o backend guarda (o canvas
  /// desenha um campo "Local" só).
  Widget _buildPlaceRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            key: const Key('campo-cidade'),
            label: 'Cidade',
            controller: _cityController,
            icon: AppIcons.place,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            enabled: _fieldsEnabled,
            errorText: _viewModel.cityError,
            onChanged: _viewModel.setCity,
          ),
        ),
        const SizedBox(width: AppSpacing.md - 2),
        SizedBox(
          width: AppSpacing.huge * 2,
          child: AppTextField(
            key: const Key('campo-uf'),
            label: 'UF',
            controller: _stateController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
              LengthLimitingTextInputFormatter(2),
              const _UpperCaseFormatter(),
            ],
            enabled: _fieldsEnabled,
            errorText: _viewModel.stateError,
            onChanged: _viewModel.setState,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return AppTextField(
      key: const Key('campo-observacoes'),
      label: 'Observações para os consultores',
      controller: _notesController,
      minLines: 4,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      enabled: _fieldsEnabled,
      onChanged: _viewModel.setNotes,
    );
  }

  /// Destrutivo e sem volta: mora no fim da tela, em contorno vermelho, longe
  /// do "Salvar alterações" (canvas "3b"). A consequência vem no diálogo,
  /// antes do toque que cancela.
  Widget _buildCancelButton(bool isOffline) {
    return AppDangerOutlineButton(
      label: 'Cancelar sessão',
      icon: AppIcons.cancelSession,
      isLoading: _viewModel.isCancelling,
      onPressed: _fieldsEnabled && !isOffline ? _confirmCancel : null,
    );
  }

  /// A falha do salvar ou do cancelar (que compartilham a mensagem) aparece
  /// aqui, acima do botão que o admin acabou de tocar, como no Resumo: dentro
  /// da lista ela podia ficar abaixo da dobra, e a única pista da falha seria o
  /// botão voltar a habilitar.
  ///
  /// Com o teclado aberto, o rodapé fica só com os dois botões: nem o aviso de
  /// falha nem a dica "Disponível quando houver conexão" aparecem. Num celular
  /// baixo com a fonte ampliada, o que sobra acima do teclado não comporta o
  /// aviso, e o rodapé estourava (RenderFlex) até a primeira tecla, que já o
  /// apagava; o teclado só sobe depois da falha porque `_save` tira o foco
  /// antes de enviar. Fechado o teclado, o aviso e a dica voltam. Os botões não
  /// mudam, nem desabilitados offline: o motivo segue escrito na faixa de
  /// offline do topo.
  Widget _buildFooter(bool isOffline, bool keyboardOpen) {
    final error = _viewModel.errorMessage;

    // Recuos e vão do canvas "3b" (12 em cima, 16 nos lados e embaixo, vão de
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
            label: 'Salvar alterações',
            icon: AppIcons.save,
            size: AppCtaSize.large,
            isLoading: _viewModel.isSaving,
            onPressed: _viewModel.canSave && !isOffline ? _save : null,
          ),
          if (isOffline && _viewModel.canEdit && !keyboardOpen) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Text(
              'Disponível quando houver conexão',
              style: AppTypography.meta,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppTextButton(
            label: 'Descartar',
            tone: AppTextButtonTone.neutral,
            onPressed: _viewModel.isBusy ? null : _discard,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await _viewModel.save();
    if (!saved || !mounted) return;

    // O SnackBar é do `ScaffoldMessenger` do app: continua na tela de baixo.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados do treinamento atualizados.')),
    );
    Navigator.of(context).pop(true);
  }

  /// "Descartar" é um pedido explícito: sai sem perguntar.
  void _discard() => Navigator.of(context).pop();

  Future<void> _confirmLeave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar as alterações?'),
        content: const Text(
          'O que você mudou nos dados do treinamento ainda não foi salvo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmCancel() async {
    final count = _viewModel.inEvaluationCount;
    final inEvaluation = switch (count) {
      0 => '',
      1 => ' Há 1 participante em avaliação agora.',
      _ => ' Há $count participantes em avaliação agora.',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar a sessão?'),
        content: Text(
          'Ninguém mais poderá ser avaliado nesta sessão, e ela sai da lista '
          'de sessões do app. Não dá para desfazer.$inEvaluation',
        ),
        actions: [
          // "Voltar", e não "Cancelar": aqui "cancelar" é a própria ação.
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancelar sessão'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final cancelled = await _viewModel.cancelSession();
    if (!cancelled || !mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sessão cancelada.')));
    // A sessão cancelada some da Home (decisão de 20/09/2026): o detalhe que
    // ficou embaixo não tem mais para onde voltar.
    context.go(AppRoutes.home);
  }

  Widget _buildSkeleton() {
    return ListView(
      key: const Key('session-edit-skeleton'),
      children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
    );
  }
}

/// Mostra em maiúsculas o que for digitado na UF, mesmo num teclado que não
/// respeita o `TextCapitalization.characters`.
class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
