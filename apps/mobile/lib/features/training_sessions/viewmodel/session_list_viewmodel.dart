import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/session_repository.dart';
import 'session_list_state.dart';

part 'session_list_viewmodel.g.dart';

@riverpod
class SessionListViewModel extends _$SessionListViewModel {
  @override
  SessionListState build() {
    loadSessions();
    return const SessionListState.loading();
  }

  Future<void> loadSessions() async {
    state = const SessionListState.loading();
    try {
      final sessions = await ref.read(sessionRepositoryProvider).getSessions();
      state = SessionListState.data(sessions);
    } catch (e) {
      state = SessionListState.error(e.toString());
    }
  }
}
