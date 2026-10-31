import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/device_data_service.dart';
import '../../utils/result.dart';

/// Para onde a abertura vai.
enum SplashOutcome {
  home,
  login,

  /// O app fala com outro servidor e não conseguiu apagar o que era do
  /// anterior: a abertura para e avisa (Fase 8D).
  resetFailed,
}

/// Decide, na abertura, se o app vai para a Home ou para o Login.
class SplashViewModel extends ChangeNotifier {
  SplashViewModel({
    required AuthRepository authRepository,
    required DeviceDataService deviceData,
    this.apiBaseUrl = AppConfig.apiBaseUrl,
  })  : _authRepository = authRepository,
        _deviceData = deviceData;

  final AuthRepository _authRepository;
  final DeviceDataService _deviceData;

  /// O endereço da API deste build.
  final String apiBaseUrl;

  /// Confere se o servidor mudou (e, se mudou, apaga o aparelho) e depois
  /// tenta retomar a sessão salva.
  ///
  /// Se a troca de servidor não conseguiu apagar o aparelho, não segue nem
  /// para o login: quem entrasse levaria a fila do servidor anterior para o
  /// novo, com ids que lá não existem.
  Future<SplashOutcome> decideInitialRoute() async {
    try {
      await _deviceData.resetIfServerChanged(apiBaseUrl);
    } catch (_) {
      return SplashOutcome.resetFailed;
    }
    final result = await _authRepository.restoreSession();
    return result is Success ? SplashOutcome.home : SplashOutcome.login;
  }
}
