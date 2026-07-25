import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/api_client.dart';
import 'training_session.dart';

part 'session_repository.g.dart';

@riverpod
SessionRepository sessionRepository(SessionRepositoryRef ref) {
  return SessionRepository(ref.watch(apiClientProvider));
}

class SessionRepository {
  final _dio;
  SessionRepository(this._dio);

  Future<List<TrainingSession>> getSessions() async {
    final response = await _dio.get('/training-sessions');
    return (response.data as List)
        .map((json) => TrainingSession.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
