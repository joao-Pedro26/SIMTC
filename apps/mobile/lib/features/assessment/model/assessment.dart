import 'package:freezed_annotation/freezed_annotation.dart';
import 'assessment_item.dart';

part 'assessment.freezed.dart';
part 'assessment.g.dart';

@freezed
class Assessment with _$Assessment {
  const factory Assessment({
    required String id,
    required String trainingParticipantId,
    required String consultantId,
    required DateTime date,
    required DateTime startTime,
    DateTime? endTime,
    @Default([]) List<AssessmentItem> items,
    @Default(false) bool synced,
  }) = _Assessment;

  factory Assessment.fromJson(Map<String, dynamic> json) => _$AssessmentFromJson(json);
}
