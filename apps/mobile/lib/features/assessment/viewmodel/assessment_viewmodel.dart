import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/assessment_item.dart';
import '../model/assessment_repository.dart';
import '../viewmodel/assessment_state.dart';
import '../../../design_system/components/assessment/note_selector.dart';

part 'assessment_viewmodel.g.dart';

@riverpod
class AssessmentViewModel extends _$AssessmentViewModel {
  @override
  AssessmentState build(String trainingParticipantId) {
    return AssessmentState(
      trainingParticipantId: trainingParticipantId,
      startTime: DateTime.now(),
    );
  }

  void markInfraction(String infractionId, String infractionNoteId, NoteType note, int deduction) {
    final updated = state.items.where((i) => i.infractionId != infractionId).toList()
      ..add(AssessmentItem(
        infractionId: infractionId,
        infractionNoteId: infractionNoteId,
        noteType: note,
        deduction: deduction,
      ));
    state = state.copyWith(items: updated);
  }

  void setEndTime(DateTime time) {
    state = state.copyWith(endTime: time);
  }

  Future<void> save() async {
    if (!state.canSave) return;
    state = state.copyWith(isSaving: true);
    try {
      await ref.read(assessmentRepositoryProvider).saveLocally(state);
      state = state.copyWith(isSaving: false, saved: true);
    } catch (e) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }
}
