import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../features/auth/view/login_page.dart';
import '../features/training_sessions/view/session_list_page.dart';
import '../features/training_sessions/view/session_detail_page.dart';
import '../features/participants/view/participant_list_page.dart';
import '../features/assessment/view/assessment_page.dart';

part 'router.g.dart';

@riverpod
GoRouter router(RouterRef ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      // TODO: checar token salvo — redirecionar para /sessions se logado
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/sessions',
        builder: (context, state) => const SessionListPage(),
        routes: [
          GoRoute(
            path: ':sessionId',
            builder: (context, state) => SessionDetailPage(
              sessionId: state.pathParameters['sessionId']!,
            ),
            routes: [
              GoRoute(
                path: 'participants',
                builder: (context, state) => ParticipantListPage(
                  sessionId: state.pathParameters['sessionId']!,
                ),
              ),
              GoRoute(
                path: 'assess/:participantId',
                builder: (context, state) => AssessmentPage(
                  sessionId: state.pathParameters['sessionId']!,
                  trainingParticipantId: state.pathParameters['participantId']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
