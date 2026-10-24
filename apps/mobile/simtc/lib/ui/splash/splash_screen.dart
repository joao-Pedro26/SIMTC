import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/device_data_service.dart';
import '../../router.dart';
import '../core/form_factor.dart';
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
      deviceData: context.read<DeviceDataService>(),
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
    // Tablet (quadros "4a" e "4o", iguais nas duas posições): logo de 200 e
    // barra de 220. O quadro põe a logo numa caixa branca com 30 de recuo
    // e 36 de vão até a barra — 66 entre a logo e a barra.
    final tablet = context.isTablet;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(height: tablet ? _tabletLogoHeight : 130),
            SizedBox(
              height: tablet ? _tabletGap : AppSpacing.xxl + AppSpacing.xs,
            ),
            _buildProgress(width: tablet ? _tabletBarWidth : 140),
          ],
        ),
      ),
    );
  }

  static const double _tabletLogoHeight = 200;
  static const double _tabletGap = AppSpacing.huge + AppSpacing.lg + 2;
  static const double _tabletBarWidth = 220;

  Widget _buildLogo({required double height}) {
    return Image.asset(
      'assets/images/logo-simtc.png',
      height: height,
      semanticLabel: 'SIM Treinamentos',
    );
  }

  Widget _buildProgress({required double width}) {
    return SizedBox(
      width: width,
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
