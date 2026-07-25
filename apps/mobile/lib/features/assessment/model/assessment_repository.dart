import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../viewmodel/assessment_state.dart';

part 'assessment_repository.g.dart';

@riverpod
AssessmentRepository assessmentRepository(AssessmentRepositoryRef ref) {
  return AssessmentRepository();
}

class AssessmentRepository {
  /// Salva avaliação localmente com synced=false
  Future<void> saveLocally(AssessmentState state) async {
    // TODO: implementar com Drift DAO
    // dao.insertAssessment(state.toEntity());
  }

  /// Busca avaliações não sincronizadas
  Future<List<AssessmentState>> getPending() async {
    // TODO: implementar com Drift DAO
    return [];
  }
}
