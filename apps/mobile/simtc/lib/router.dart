import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'data/repositories/auth_repository.dart';
import 'ui/auth/login_screen.dart';
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/sessions/sessions_screen.dart';
import 'ui/splash/splash_screen.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String designSystem = '/ds';
}

/// Rotas do app. O redirecionamento observa o `AuthRepository`: entrar ou sair
/// da sessão troca a tela sem nenhuma navegação manual espalhada pelo código.
GoRouter createRouter(AuthRepository auth) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
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
