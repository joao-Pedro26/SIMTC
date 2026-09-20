import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'splash_viewmodel.dart';

/// Tela 1.1 do canvas: logo centralizada e uma barra fina de progresso,
/// enquanto o app tenta retomar a sessão salva. Sem texto de carregamento.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final viewModel = SplashViewModel(
      authRepository: context.read<AuthRepository>(),
    );

    var isSignedIn = false;
    try {
      isSignedIn = await viewModel.decideInitialRoute();
    } catch (error, stack) {
      // A abertura nunca pode terminar numa tela parada. Qualquer falha
      // inesperada vai para o log e manda o usuário para o login, de onde ele
      // consegue sair — travar aqui só se resolve reinstalando o app.
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    } finally {
      viewModel.dispose();
    }

    if (!mounted) return;
    context.go(isSignedIn ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(),
            const SizedBox(height: AppSpacing.xxl + AppSpacing.xs),
            _buildProgress(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo-simtc.png',
      height: 130,
      semanticLabel: 'SIM Treinamentos',
    );
  }

  Widget _buildProgress() {
    return SizedBox(
      width: 140,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: const LinearProgressIndicator(
          minHeight: 4,
          backgroundColor: AppColors.progressTrack,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
}
