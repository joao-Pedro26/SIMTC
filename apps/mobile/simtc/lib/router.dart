import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/repositories/auth_repository.dart';
import 'ui/add_participant/add_participant_screen.dart';
import 'ui/auth/login_screen.dart';
import 'ui/checklist/checklist_screen.dart';
import 'ui/core/form_factor.dart';
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/result/result_screen.dart';
import 'ui/session_consultants/session_consultants_screen.dart';
import 'ui/session_detail/session_detail_screen.dart';
import 'ui/session_edit/session_edit_screen.dart';
import 'ui/sessions/sessions_screen.dart';
import 'ui/sessions/sessions_split_view.dart';
import 'ui/splash/splash_screen.dart';
import 'ui/summary/summary_screen.dart';
import 'ui/sync/sync_screen.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String designSystem = '/ds';

  /// Aba "Sincronizar" (tela 1.9, Fase 5A).
  static const String sync = '/sync';

  /// Detalhe da sessão (tela 1.4).
  static String sessionDetail(String sessionId) => '/sessions/$sessionId';

  /// "Dados do treinamento" (tela 1.12, Fase 6A), só para ADMIN.
  static String sessionEdit(String sessionId) => '/sessions/$sessionId/edit';

  /// "Adicionar participante" (tela 1.11, Fase 6A), só para ADMIN.
  static String addParticipant(String sessionId) =>
      '/sessions/$sessionId/participants/new';

  /// "Consultores" da sessão (tela 1.13, Fase 6B), só para ADMIN.
  static String sessionConsultants(String sessionId) =>
      '/sessions/$sessionId/consultants';

  /// Checklist do participante (Fase 4). [fromResult]: aberto pelo
  /// "Reavaliar" do Resultado, que continua embaixo — o voltar leva a ele.
  static String participantChecklist(
    String sessionId,
    String participantId, {
    bool fromResult = false,
  }) =>
      '/sessions/$sessionId/participants/$participantId/checklist'
      '${fromResult ? '?origem=resultado' : ''}';

  /// "Conferir e finalizar" (tela 1.6, Fase 5A), aberta pelo checklist.
  static String participantSummary(String sessionId, String participantId) =>
      '/sessions/$sessionId/participants/$participantId/summary';

  /// Resultado do participante (tela 1.8, Fase 5B). [justConfirmed]: aberto
  /// logo depois do "Confirmar" da tela 1.6 — o rodapé é o "Próximo
  /// participante".
  static String participantResult(
    String sessionId,
    String participantId, {
    bool justConfirmed = false,
  }) =>
      '/sessions/$sessionId/participants/$participantId/result'
      '${justConfirmed ? '?confirmada=1' : ''}';
}

/// No tablet, `/home` e `/sessions/:id` são a mesma página (a lista e o
/// detalhe juntos, `SessionsSplitView`): a chave igual faz o `Navigator`
/// atualizar a página em vez de trocar uma por outra, e o estado de lista e
/// detalhe atravessa a troca de rota e o giro do aparelho.
const ValueKey<String> _sessionsSplitPageKey = ValueKey('sessions-split');

Page<void> _sessionsPage(
  BuildContext context,
  GoRouterState state, {
  required Widget phone,
  String? selectedSessionId,
}) {
  if (FormFactorScope.of(context) == FormFactor.tablet) {
    return NoTransitionPage<void>(
      key: _sessionsSplitPageKey,
      child: SessionsSplitView(selectedSessionId: selectedSessionId),
    );
  }
  return MaterialPage<void>(key: state.pageKey, child: phone);
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
        pageBuilder: (context, state) =>
            _sessionsPage(context, state, phone: const SessionsScreen()),
      ),
      GoRoute(
        path: AppRoutes.sync,
        builder: (context, state) => const SyncScreen(),
      ),
      GoRoute(
        path: '/sessions/:sessionId',
        pageBuilder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return _sessionsPage(
            context,
            state,
            phone: SessionDetailScreen(sessionId: sessionId),
            selectedSessionId: sessionId,
          );
        },
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => SessionEditScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
          GoRoute(
            path: 'participants/new',
            builder: (context, state) => AddParticipantScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
          GoRoute(
            path: 'consultants',
            builder: (context, state) => SessionConsultantsScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
          GoRoute(
            path: 'participants/:participantId/checklist',
            builder: (context, state) => ChecklistScreen(
              sessionId: state.pathParameters['sessionId']!,
              participantId: state.pathParameters['participantId']!,
              fromResult: state.uri.queryParameters['origem'] == 'resultado',
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
            builder: (context, state) => ResultScreen(
              sessionId: state.pathParameters['sessionId']!,
              participantId: state.pathParameters['participantId']!,
              justConfirmed: state.uri.queryParameters['confirmada'] == '1',
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
