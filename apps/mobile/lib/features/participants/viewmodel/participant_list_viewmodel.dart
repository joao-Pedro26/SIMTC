import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/participant_repository.dart';
import 'participant_list_state.dart';

part 'participant_list_viewmodel.g.dart';

@riverpod
class ParticipantListViewModel extends _$ParticipantListViewModel {
  @override
  ParticipantListState build(String sessionId) {
    loadParticipants(sessionId);
    return const ParticipantListState.loading();
  }

  Future<void> loadParticipants(String sessionId) async {
    state = const ParticipantListState.loading();
    try {
      final list = await ref.read(participantRepositoryProvider).getBySession(sessionId);
      state = ParticipantListState.data(list);
    } catch (e) {
      state = ParticipantListState.error(e.toString());
    }
  }
}
