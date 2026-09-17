import 'package:flutter/material.dart';
import '../../data/models/evaluation_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/evaluation_repository.dart';

class DashboardViewModel extends ChangeNotifier {
  final EvaluationRepository _evaluationRepository;
  final AuthRepository _authRepository;

  DashboardViewModel({
    required EvaluationRepository evaluationRepository,
    required AuthRepository authRepository,
  })  : _evaluationRepository = evaluationRepository,
        _authRepository = authRepository;

  List<EvaluationModel> _evaluations = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<EvaluationModel> get evaluations => _evaluations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get userName => _authRepository.currentUser?.name ?? 'Instrutor';

  Future<void> loadEvaluations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _evaluationRepository.getEvaluations();
    _isLoading = false;

    if (result.isSuccess) {
      _evaluations = result.dataOrNull ?? [];
    } else {
      _errorMessage = 'Erro ao carregar avaliações.';
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _authRepository.logout();
  }
}
