import '../../utils/api_constants.dart';
import '../../utils/result.dart';
import '../models/evaluation_model.dart';
import '../services/api/api_service.dart';

class EvaluationRepository {
  final ApiService _apiService;

  EvaluationRepository({
    ApiService? apiService,
  }) : _apiService = apiService ?? ApiService();

  final List<EvaluationModel> _localEvaluations = [
    EvaluationModel(
      id: 'eval_1',
      title: 'Treinamento Prático de Operação',
      description: 'Avaliação de desempenho em campo do operador.',
      score: 9.5,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      status: EvaluationStatus.completed,
    ),
    EvaluationModel(
      id: 'eval_2',
      title: 'Procedimentos de Segurança',
      description: 'Verificação teórica e checklist de inspeção de EPI.',
      score: 8.8,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      status: EvaluationStatus.completed,
    ),
    EvaluationModel(
      id: 'eval_3',
      title: 'Manutenção Preventiva',
      description: 'Inspeção de rotina do veículo e equipamentos.',
      score: 10.0,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      status: EvaluationStatus.synced,
    ),
  ];

  Future<Result<List<EvaluationModel>>> getEvaluations() async {
    final result = await _apiService.get<List<EvaluationModel>>(
      ApiConstants.evaluations,
      parser: (data) {
        final list = data as List<dynamic>;
        return list
            .map((e) => EvaluationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );

    if (result is Success<List<EvaluationModel>>) {
      return result;
    } else {
      // Fallback local mock data
      return Success(List.unmodifiable(_localEvaluations));
    }
  }

  Future<Result<EvaluationModel>> saveEvaluation(EvaluationModel evaluation) async {
    _localEvaluations.insert(0, evaluation);

    final result = await _apiService.post<EvaluationModel>(
      ApiConstants.evaluations,
      data: evaluation.toJson(),
      parser: (data) => EvaluationModel.fromJson(data as Map<String, dynamic>),
    );

    if (result is Success<EvaluationModel>) {
      return result;
    } else {
      return Success(evaluation);
    }
  }
}
