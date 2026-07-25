import 'package:freezed_annotation/freezed_annotation.dart';
import '../model/participant.dart';

part 'participant_list_state.freezed.dart';

@freezed
class ParticipantListState with _$ParticipantListState {
  const factory ParticipantListState.loading()                           = _Loading;
  const factory ParticipantListState.data(List<Participant> participants) = _Data;
  const factory ParticipantListState.error(String message)               = _Error;
}
