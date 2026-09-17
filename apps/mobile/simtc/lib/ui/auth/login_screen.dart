import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../utils/app_colors.dart';
import '../core/widgets/custom_button.dart';
import '../core/widgets/custom_text_field.dart';
import 'login_viewmodel.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 36),
                _buildFormFields(viewModel),
                if (viewModel.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildErrorMessage(viewModel.errorMessage!),
                ],
                const SizedBox(height: 28),
                _buildSubmitButton(context, viewModel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Icon(
          Icons.assignment_turned_in_rounded,
          size: 72,
          color: AppColors.primary,
        ),
        SizedBox(height: 16),
        Text(
          'SIMTC Treinamentos',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Acesse sua conta para realizar e visualizar avaliações',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields(LoginViewModel viewModel) {
    return Column(
      children: [
        CustomTextField(
          label: 'E-mail',
          hint: 'seu.email@simtc.com.br',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
          onChanged: viewModel.setEmail,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Senha',
          hint: '••••••••',
          obscureText: viewModel.obscurePassword,
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              viewModel.obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: viewModel.togglePasswordVisibility,
          ),
          onChanged: viewModel.setPassword,
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String errorMessage) {
    return Text(
      errorMessage,
      style: const TextStyle(
        color: AppColors.error,
        fontSize: 13,
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context, LoginViewModel viewModel) {
    return CustomButton(
      label: 'Entrar',
      isLoading: viewModel.isLoading,
      onPressed: () async {
        final success = await viewModel.login();
        if (success && context.mounted) {
          context.go('/dashboard');
        }
      },
    );
  }
}
