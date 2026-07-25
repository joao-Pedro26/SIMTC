import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/ds.dart';

class SessionDetailPage extends ConsumerWidget {
  final String sessionId;
  const SessionDetailPage({required this.sessionId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: carregar sessão pelo ID
    return SimtcScaffold(
      title: 'Treinamento',
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SimtcButton(
              label: 'Ver Participantes',
              onPressed: () => context.push('/sessions/$sessionId/participants'),
            ),
          ],
        ),
      ),
    );
  }
}
