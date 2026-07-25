import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/ds.dart';
import '../viewmodel/participant_list_viewmodel.dart';
import '../viewmodel/participant_list_state.dart';

class ParticipantListPage extends ConsumerWidget {
  final String sessionId;
  const ParticipantListPage({required this.sessionId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(participantListViewModelProvider(sessionId));
    final vm    = ref.read(participantListViewModelProvider(sessionId).notifier);

    return SimtcScaffold(
      title: 'Participantes',
      body: switch (state) {
        _Loading() => const SimtcLoading(),
        _Error(:final message) => SimtcErrorState(
            message: message,
            onRetry: () => vm.loadParticipants(sessionId),
          ),
        _Data(:final participants) when participants.isEmpty => const SimtcEmptyState(
            message: 'Nenhum participante inscrito',
            icon: Icons.people_outline,
          ),
        _Data(:final participants) => ListView.separated(
            padding: const EdgeInsets.all(SimtcSpacing.md),
            itemCount: participants.length,
            separatorBuilder: (_, __) => const SizedBox(height: SimtcSpacing.xs),
            itemBuilder: (context, i) {
              final p = participants[i];
              return Card(
                child: ListTile(
                  title: Text(p.name, style: SimtcTypography.headingSm),
                  subtitle: Text('CPF: ${p.cpf}', style: SimtcTypography.caption),
                  trailing: p.status == 'APROVADO'
                      ? const Icon(Icons.check_circle, color: SimtcColors.approved)
                      : const Icon(Icons.chevron_right),
                  onTap: p.status == 'PENDENTE' || p.status == 'EM_AVALIACAO'
                      ? () => context.push('/sessions/$sessionId/assess/${p.trainingParticipantId}')
                      : null,
                ),
              );
            },
          ),
      },
    );
  }
}
