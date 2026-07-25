import 'package:freezed_annotation/freezed_annotation.dart';

part 'participant.freezed.dart';
part 'participant.g.dart';

@freezed
class Participant with _$Participant {
  const factory Participant({
    required String id,
    required String trainingParticipantId,
    required String name,
    required String cpf,
    String? email,
    String? cnhCategory,
    required String status, // PENDENTE | EM_AVALIACAO | APROVADO | NECESSITA_REAVALIACAO
  }) = _Participant;

  factory Participant.fromJson(Map<String, dynamic> json) => _$ParticipantFromJson(json);
}
