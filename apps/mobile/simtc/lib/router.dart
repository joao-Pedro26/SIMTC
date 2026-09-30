import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'data/repositories/auth_repository.dart';
import 'ui/auth/login_screen.dart';
import 'ui/checklist/checklist_screen.dart';
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/evaluation/evaluation_placeholder_screen.dart';
import 'ui/session_detail/session_detail_screen.dart';
import 'ui/sessions/sessions_screen.dart';
import 'ui/splash/splash_screen.dart';
import 'ui/summary/summary_screen.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String designSystem = '/ds';

  /// Detalhe da sessão (tela 1.4).
  static String sessionDetail(String sessionId) => '/sessions/$sessionId';

  /// Checklist do participante (Fase 4).
  static String participantChecklist(String sessionId, String participantId) =>
      '/sessions/$sessionId/participants/$participantId/checklist';

  /// "Conferir e finalizar" (tela 1.6, Fase 5A), aberta pelo checklist.
  static String participantSummary(String sessionId, String participantId) =>
      '/sessions/$sessionId/participants/$participantId/summary';

  /// Resultado do participante (Fase 5) — por ora, uma tela provisória.
  static String participantResult(String sessionId, String participantId) =>
      '/sessions/$sessionId/participants/$participantId/result';
}

/// Rotas do app. O redirecionamento observa o `AuthRepository`: entrar ou sair
/// da sessão troca a tela sem nenhuma navegação manual espalhada pelo código.
///
/// `initialLocation` só muda nos testes, para abrir direto numa tela sem
/// passar pela abertura.
GoRouter createRouter(
  AuthRepository auth, {
  String initialLocation = AppRoutes.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: auth,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const SessionsScreen(),
      ),
      GoRoute(
        path: '/sessions/:sessionId',
        builder: (context, state) => SessionDetailScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
        routes: [
          GoRoute(
            path: 'participants/:participantId/checklist',
            builder: (context, state) => ChecklistScreen(
              sessionId: state.pathParameters['sessionId']!,
              participantId: state.pathParameters['participantId']!,
            ),
          ),
          GoRoute(
            path: 'participants/:participantId/summary',
            builder: (context, state) => SummaryScreen(
              participantId: state.pathParameters['participantId']!,
            ),
          ),
          GoRoute(
            path: 'participants/:participantId/result',
            builder: (context, state) => EvaluationPlaceholderScreen(
              kind: EvaluationPlaceholderKind.result,
              participantName: state.extra as String?,
            ),
          ),
        ],
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.designSystem,
          builder: (context, state) => const DsGalleryScreen(),
        ),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;

      // A splash decide sozinha para onde ir depois de tentar retomar a sessão.
      if (location == AppRoutes.splash) return null;
      if (kDebugMode && location == AppRoutes.designSystem) return null;

      final isAuthenticated = auth.isAuthenticated;
      if (!isAuthenticated && location != AppRoutes.login) return AppRoutes.login;
      if (isAuthenticated && location == AppRoutes.login) return AppRoutes.home;
      return null;
    },
  );
}
