import 'package:go_router/go_router.dart';
import 'data/models/evaluation_model.dart';
import 'ui/auth/login_screen.dart';
import 'ui/dashboard/dashboard_screen.dart';
import 'ui/evaluation/evaluation_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/evaluation',
      builder: (context, state) {
        final evaluation = state.extra as EvaluationModel?;
        return EvaluationScreen(evaluation: evaluation);
      },
    ),
  ],
);
