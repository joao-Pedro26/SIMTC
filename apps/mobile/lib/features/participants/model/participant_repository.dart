import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/api_client.dart';
import 'participant.dart';

part 'participant_repository.g.dart';

@riverpod
ParticipantRepository participantRepository(ParticipantRepositoryRef ref) {
  return ParticipantRepository(ref.watch(apiClientProvider));
}

class ParticipantRepository {
  final _dio;
  ParticipantRepository(this._dio);

  Future<List<Participant>> getBySession(String sessionId) async {
    final response = await _dio.get('/training-sessions/$sessionId/participants');
    return (response.data as List)
        .map((json) => Participant.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
