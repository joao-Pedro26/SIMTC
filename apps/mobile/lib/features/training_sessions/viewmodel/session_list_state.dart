import 'package:freezed_annotation/freezed_annotation.dart';
import '../model/training_session.dart';

part 'session_list_state.freezed.dart';

@freezed
class SessionListState with _$SessionListState {
  const factory SessionListState.loading()                          = _Loading;
  const factory SessionListState.data(List<TrainingSession> sessions) = _Data;
  const factory SessionListState.error(String message)             = _Error;
}
