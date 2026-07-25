import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/ds.dart';
import '../viewmodel/session_list_viewmodel.dart';
import '../viewmodel/session_list_state.dart';

class SessionListPage extends ConsumerWidget {
  const SessionListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionListViewModelProvider);

    return SimtcScaffold(
      title: 'Meus Treinamentos',
      body: switch (state) {
        _Loading() => const SimtcLoading(),
        _Error(:final message) => SimtcErrorState(
            message: message,
            onRetry: () => ref.read(sessionListViewModelProvider.notifier).loadSessions(),
          ),
        _Data(:final sessions) when sessions.isEmpty => const SimtcEmptyState(
            message: 'Nenhum treinamento encontrado',
            subtitle: 'Você ainda não possui sessões atribuídas.',
            icon: Icons.event_busy,
          ),
        _Data(:final sessions) => RefreshIndicator(
            onRefresh: () => ref.read(sessionListViewModelProvider.notifier).loadSessions(),
            child: ListView.separated(
              padding: const EdgeInsets.all(SimtcSpacing.md),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: SimtcSpacing.sm),
              itemBuilder: (context, i) {
                final s = sessions[i];
                return Card(
                  child: ListTile(
                    title: Text(s.courseName, style: SimtcTypography.headingSm),
                    subtitle: Text('${s.companyName} • ${s.city}/${s.state}', style: SimtcTypography.caption),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/sessions/${s.id}'),
                  ),
                );
              },
            ),
          ),
      },
    );
  }
}
