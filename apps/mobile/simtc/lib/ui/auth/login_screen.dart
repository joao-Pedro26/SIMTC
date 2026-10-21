import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_checkbox.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/inline_notice.dart';
import 'login_viewmodel.dart';

/// Tela 1.2 do canvas.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LoginViewModel>(
      create: (context) => LoginViewModel(
        authRepository: context.read<AuthRepository>(),
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Consumer<LoginViewModel>(
            builder: (context, viewModel, _) => _buildBody(context, viewModel),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, LoginViewModel viewModel) {
    final form = _buildForm(context, viewModel);
    if (context.isExpandedLayout) return _buildTabletLandscape(form);
    if (context.isTablet) return _buildTabletPortrait(form);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.huge,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLogo(),
              const SizedBox(height: AppSpacing.xxxl),
              form,
            ],
          ),
        ),
      ],
    );
  }

  /// Quadro "4b": a logo num painel de 520 à esquerda; o formulário, com até
  /// 440 de largura, centrado no resto. Rola quando o teclado sobe.
  Widget _buildTabletLandscape(Widget form) {
    return Row(
      children: [
        SizedBox(
          width: _tabletLogoPanelWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _tabletLogoInset),
            child: Center(child: _buildLogo(height: _tabletLogoHeight)),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: _tabletFormInset,
                vertical: AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _tabletFormWidth),
                child: form,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Quadro "4p": os dois painéis empilham — a logo em cima (56 de recuo, 32
  /// embaixo), o formulário na mesma coluna de 440, e o conjunto centrado na
  /// altura.
  Widget _buildTabletPortrait(Widget form) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _tabletFormInset,
          0,
          _tabletFormInset,
          AppSpacing.huge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                0,
                _tabletLogoInset,
                0,
                AppSpacing.xxxl,
              ),
              child: _buildLogo(height: _tabletLogoHeight),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _tabletFormWidth),
              child: form,
            ),
          ],
        ),
      ),
    );
  }

  /// Medidas dos quadros "4b" e "4p".
  static const double _tabletLogoHeight = 230;
  static const double _tabletLogoPanelWidth = 520;
  static const double _tabletLogoInset = AppSpacing.huge + AppSpacing.sm;
  static const double _tabletFormWidth = 440;
  static const double _tabletFormInset = AppSpacing.huge + AppSpacing.lg;

  /// Os campos, o "Entrar" e os avisos — os mesmos em qualquer formato.
  Widget _buildForm(BuildContext context, LoginViewModel viewModel) {
    final isOffline = context.watch<ConnectivityService>().isOffline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEmailField(viewModel),
        const SizedBox(height: AppSpacing.lg + 2),
        _buildPasswordField(viewModel),
        const SizedBox(height: AppSpacing.md),
        _buildOptionsRow(viewModel),
        if (viewModel.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineNotice(
            icon: AppIcons.needsReview,
            message: viewModel.errorMessage!,
            tone: NoticeTone.danger,
          ),
        ],
        if (viewModel.infoMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineNotice(
            icon: AppIcons.email,
            message: viewModel.infoMessage!,
            tone: NoticeTone.success,
          ),
        ],
        const SizedBox(height: AppSpacing.lg + 2),
        _buildSubmitButton(context, viewModel),
        if (isOffline) ...[
          const SizedBox(height: AppSpacing.xxl),
          _buildOfflineNotice(),
        ],
      ],
    );
  }

  Widget _buildLogo({double height = 150}) {
    return Center(
      child: Image.asset(
        'assets/images/logo-simtc.png',
        height: height,
        semanticLabel: 'SIM Treinamentos',
      ),
    );
  }

  Widget _buildEmailField(LoginViewModel viewModel) {
    return AppTextField(
      label: 'E-mail',
      controller: _emailController,
      icon: AppIcons.email,
      hintText: 'seu.email@simtc.com.br',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.username, AutofillHints.email],
      enabled: !viewModel.isSubmitting,
      onSubmitted: (_) => _passwordFocus.requestFocus(),
      onChanged: viewModel.setEmail,
    );
  }

  Widget _buildPasswordField(LoginViewModel viewModel) {
    return AppTextField(
      label: 'Senha',
      controller: _passwordController,
      focusNode: _passwordFocus,
      icon: AppIcons.password,
      obscureText: viewModel.obscurePassword,
      onToggleObscure: viewModel.toggleObscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      enabled: !viewModel.isSubmitting,
      onSubmitted: (_) => _submit(context, viewModel),
      onChanged: viewModel.setPassword,
    );
  }

  Widget _buildOptionsRow(LoginViewModel viewModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: AppCheckbox(
            value: viewModel.keepSignedIn,
            label: 'Manter conectado',
            onChanged: viewModel.isSubmitting ? (_) {} : viewModel.setKeepSignedIn,
          ),
        ),
        TextButton(
          onPressed: viewModel.isSubmitting ? null : viewModel.requestPasswordReset,
          child: Text('Esqueci a senha', style: AppTypography.link),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context, LoginViewModel viewModel) {
    return AppPrimaryButton(
      label: 'Entrar',
      isLoading: viewModel.isSubmitting,
      onPressed: viewModel.canSubmit ? () => _submit(context, viewModel) : null,
    );
  }

  Widget _buildOfflineNotice() {
    return const InlineNotice(
      icon: AppIcons.noSignal,
      message:
          'Sem conexão. O primeiro acesso neste aparelho precisa de internet para validar suas credenciais.',
    );
  }

  Future<void> _submit(BuildContext context, LoginViewModel viewModel) async {
    FocusScope.of(context).unfocus();
    // Entrar não navega daqui: o sucesso avisa o `AuthRepository`, e a guarda do
    // router tira o usuário do login. Navegação manual espalhada pelas telas é
    // exatamente o que essa guarda existe para evitar.
    await viewModel.submit();
  }
}
