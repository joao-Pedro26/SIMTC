import 'package:flutter/foundation.dart';

import '../../data/repositories/auth_repository.dart';
import '../../utils/result.dart';

/// Decide, na abertura, se o app vai para a Home ou para o Login.
class SplashViewModel extends ChangeNotifier {
  SplashViewModel({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  /// Tenta retomar a sessão salva. Devolve true quando consegue.
  Future<bool> decideInitialRoute() async {
    final result = await _authRepository.restoreSession();
    return result is Success;
  }
}
