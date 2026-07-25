import 'package:freezed_annotation/freezed_annotation.dart';
import '../model/assessment_item.dart';
import '../../../design_system/components/assessment/note_selector.dart';

part 'assessment_state.freezed.dart';

@freezed
class AssessmentState with _$AssessmentState {
  const factory AssessmentState({
    required String trainingParticipantId,
    required DateTime startTime,
    DateTime? endTime,
    @Default([]) List<AssessmentItem> items,
    @Default(false) bool isSaving,
    @Default(false) bool saved,
  }) = _AssessmentState;

  const AssessmentState._();

  bool get canSave => endTime != null && !isSaving;

  double get overallScore {
    if (items.isEmpty) return 100;
    final total = items.fold(0, (acc, i) => acc + i.deduction);
    return (100 - total).clamp(0, 100).toDouble();
  }
}
