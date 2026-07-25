import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../design_system/components/assessment/note_selector.dart';

part 'assessment_item.freezed.dart';
part 'assessment_item.g.dart';

@freezed
class AssessmentItem with _$AssessmentItem {
  const factory AssessmentItem({
    required String infractionId,
    required String infractionNoteId,
    required NoteType noteType,
    required int deduction,
  }) = _AssessmentItem;

  factory AssessmentItem.fromJson(Map<String, dynamic> json) => _$AssessmentItemFromJson(json);
}
