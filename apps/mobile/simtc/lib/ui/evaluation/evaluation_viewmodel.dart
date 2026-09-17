import 'package:flutter/material.dart';
import '../../data/models/evaluation_model.dart';
import '../../data/repositories/evaluation_repository.dart';

class EvaluationViewModel extends ChangeNotifier {
  final EvaluationRepository _evaluationRepository;

  EvaluationViewModel({required EvaluationRepository evaluationRepository})
      : _evaluationRepository = evaluationRepository;

  String _title = '';
  String _description = '';
  double _score = 7.0;
  bool _isSaving = false;
  String? _errorMessage;

  String get title => _title;
  String get description => _description;
  double get score => _score;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  void setTitle(String value) {
    _title = value;
    _errorMessage = null;
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value;
    _errorMessage = null;
    notifyListeners();
  }

  void setScore(double value) {
    _score = value;
    notifyListeners();
  }

  void initFromModel(EvaluationModel? model) {
    if (model != null) {
      _title = model.title;
      _description = model.description;
      _score = model.score;
    } else {
      _title = '';
      _description = '';
      _score = 7.0;
    }
    _errorMessage = null;
    _isSaving = false;
  }

  Future<bool> saveEvaluation() async {
    if (_title.trim().isEmpty) {
      _errorMessage = 'Por favor, informe o título da avaliação.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final newEval = EvaluationModel(
      id: 'eval_${DateTime.now().millisecondsSinceEpoch}',
      title: _title.trim(),
      description: _description.trim(),
      score: _score,
      createdAt: DateTime.now(),
      status: EvaluationStatus.completed,
    );

    final result = await _evaluationRepository.saveEvaluation(newEval);
    _isSaving = false;

    if (result.isSuccess) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Erro ao salvar avaliação.';
      notifyListeners();
      return false;
    }
  }
}
