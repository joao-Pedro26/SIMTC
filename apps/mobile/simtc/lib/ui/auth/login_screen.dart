import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/connectivity_service.dart';
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
    final isOffline = context.watch<ConnectivityService>().isOffline;
    final viewportHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: viewportHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.huge,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLogo(),
              const SizedBox(height: AppSpacing.xxxl),
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
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        'assets/images/logo-simtc.png',
        height: 150,
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
