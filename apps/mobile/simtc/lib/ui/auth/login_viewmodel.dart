import 'package:flutter/foundation.dart';

import '../../data/repositories/auth_repository.dart';
import '../../utils/result.dart';

/// Estado da tela de login. Nenhuma chamada de rede acontece aqui — tudo passa
/// pelo `AuthRepository`.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  String _email = '';
  String _password = '';
  bool _keepSignedIn = true;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _infoMessage;

  String get email => _email;
  String get password => _password;
  bool get keepSignedIn => _keepSignedIn;
  bool get obscurePassword => _obscurePassword;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  bool get canSubmit =>
      !_isSubmitting && _email.trim().isNotEmpty && _password.isNotEmpty;

  void setEmail(String value) {
    _email = value;
    _clearMessages();
  }

  /// A senha não é aparada: espaços podem fazer parte dela.
  void setPassword(String value) {
    _password = value;
    _clearMessages();
  }

  void setKeepSignedIn(bool value) {
    _keepSignedIn = value;
    notifyListeners();
  }

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void _clearMessages() {
    if (_errorMessage != null || _infoMessage != null) {
      _errorMessage = null;
      _infoMessage = null;
    }
    notifyListeners();
  }

  Future<bool> submit() async {
    if (!canSubmit) return false;

    _isSubmitting = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    final result = await _authRepository.login(
      email: _email,
      password: _password,
      keepSignedIn: _keepSignedIn,
    );

    _isSubmitting = false;
    switch (result) {
      case Success():
        notifyListeners();
        return true;
      case Failure(message: final message):
        _errorMessage = message ?? 'Não foi possível entrar. Tente de novo.';
        notifyListeners();
        return false;
    }
  }

  /// Pede o e-mail de redefinição. A resposta é sempre a mesma, exista a conta
  /// ou não — o backend responde 204 nos dois casos, de propósito.
  Future<void> requestPasswordReset() async {
    if (_email.trim().isEmpty) {
      _errorMessage = 'Informe o e-mail para receber o link de redefinição.';
      notifyListeners();
      return;
    }

    _isSubmitting = true;
    notifyListeners();

    final result = await _authRepository.requestPasswordReset(_email);

    _isSubmitting = false;
    switch (result) {
      case Success():
        _errorMessage = null;
        _infoMessage =
            'Se este e-mail estiver cadastrado, enviamos um link para redefinir a senha.';
      case Failure(message: final message):
        _infoMessage = null;
        _errorMessage = message ?? 'Não foi possível enviar o e-mail agora.';
    }
    notifyListeners();
  }
}
