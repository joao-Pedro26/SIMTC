import 'package:freezed_annotation/freezed_annotation.dart';

part 'training_session.freezed.dart';
part 'training_session.g.dart';

@freezed
class TrainingSession with _$TrainingSession {
  const factory TrainingSession({
    required String id,
    required String companyName,
    required String courseName,
    required String consultantName,
    required String city,
    required String state,
    String? date,
    required String status,
    required String qrCodeToken,
  }) = _TrainingSession;

  factory TrainingSession.fromJson(Map<String, dynamic> json) => _$TrainingSessionFromJson(json);
}
