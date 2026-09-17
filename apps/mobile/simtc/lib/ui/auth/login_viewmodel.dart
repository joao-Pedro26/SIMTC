import 'package:flutter/material.dart';
import '../../data/repositories/auth_repository.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;

  LoginViewModel({required AuthRepository authRepository})
      : _authRepository = authRepository;

  String _email = '';
  String _password = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  String get email => _email;
  String get password => _password;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get obscurePassword => _obscurePassword;

  void setEmail(String value) {
    _email = value;
    _errorMessage = null;
    notifyListeners();
  }

  void setPassword(String value) {
    _password = value;
    _errorMessage = null;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  Future<bool> login() async {
    if (_email.trim().isEmpty) {
      _errorMessage = 'Por favor, informe seu e-mail.';
      notifyListeners();
      return false;
    }
    if (_password.trim().isEmpty) {
      _errorMessage = 'Por favor, informe sua senha.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authRepository.login(
      email: _email.trim(),
      password: _password.trim(),
    );

    _isLoading = false;

    if (result.isSuccess) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Falha ao realizar login. Verifique suas credenciais.';
      notifyListeners();
      return false;
    }
  }
}
