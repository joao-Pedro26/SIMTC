import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/ds.dart';
import '../viewmodel/assessment_viewmodel.dart';

class AssessmentPage extends ConsumerWidget {
  final String sessionId;
  final String trainingParticipantId;

  const AssessmentPage({
    required this.sessionId,
    required this.trainingParticipantId,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assessmentViewModelProvider(trainingParticipantId));
    final vm    = ref.read(assessmentViewModelProvider(trainingParticipantId).notifier);

    return SimtcScaffold(
      title: 'Avaliação Prática',
      body: Column(
        children: [
          // TODO: renderizar categorias com infrações e NoteSelector
          // Usar CategorySection + InfractionRow (widgets/)
          Expanded(
            child: const Center(child: Text('Categorias de avaliação aqui')),
          ),
          // Rodapé com score e botão de salvar
          Container(
            padding: const EdgeInsets.all(SimtcSpacing.md),
            decoration: const BoxDecoration(
              color: SimtcColors.surface,
              border: Border(top: BorderSide(color: SimtcColors.border)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Média Geral', style: SimtcTypography.body),
                    Text(
                      '${state.overallScore.toStringAsFixed(1)} — ${_label(state.overallScore)}',
                      style: SimtcTypography.bodyBold.copyWith(
                        color: state.overallScore >= 70 ? SimtcColors.noteB : SimtcColors.noteM,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SimtcSpacing.md),
                SimtcButton(
                  label: 'Salvar Avaliação',
                  onPressed: state.canSave ? vm.save : null,
                  isLoading: state.isSaving,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(double score) {
    if (score >= 70) return '✅ Aprovado';
    return '⚠️ Necessita Reavaliação';
  }
}
