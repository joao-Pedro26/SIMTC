import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/evaluation_repository.dart';
import 'data/services/api/api_service.dart';
import 'router.dart';
import 'ui/auth/login_viewmodel.dart';
import 'ui/dashboard/dashboard_viewmodel.dart';
import 'ui/evaluation/evaluation_viewmodel.dart';
import 'utils/app_colors.dart';

class SimtcApp extends StatelessWidget {
  const SimtcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),
        // Repositories
        ProxyProvider<ApiService, AuthRepository>(
          update: (_, apiService, __) => AuthRepository(apiService: apiService),
        ),
        ProxyProvider<ApiService, EvaluationRepository>(
          update: (_, apiService, __) =>
              EvaluationRepository(apiService: apiService),
        ),
        // ViewModels
        ChangeNotifierProxyProvider<AuthRepository, LoginViewModel>(
          create: (context) => LoginViewModel(
            authRepository: context.read<AuthRepository>(),
          ),
          update: (_, authRepo, previous) =>
              previous ?? LoginViewModel(authRepository: authRepo),
        ),
        ChangeNotifierProxyProvider2<EvaluationRepository, AuthRepository,
            DashboardViewModel>(
          create: (context) => DashboardViewModel(
            evaluationRepository: context.read<EvaluationRepository>(),
            authRepository: context.read<AuthRepository>(),
          ),
          update: (_, evalRepo, authRepo, previous) =>
              previous ??
              DashboardViewModel(
                evaluationRepository: evalRepo,
                authRepository: authRepo,
              ),
        ),
        ChangeNotifierProxyProvider<EvaluationRepository, EvaluationViewModel>(
          create: (context) => EvaluationViewModel(
            evaluationRepository: context.read<EvaluationRepository>(),
          ),
          update: (_, evalRepo, previous) =>
              previous ?? EvaluationViewModel(evaluationRepository: evalRepo),
        ),
      ],
      child: MaterialApp.router(
        title: 'SIMTC Treinamentos',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            surface: AppColors.surface,
          ),
          scaffoldBackgroundColor: AppColors.background,
        ),
        routerConfig: appRouter,
      ),
    );
  }
}
