import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/device_data_service.dart';
import '../../utils/result.dart';

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
  /// tenta retomar a sessão salva. Devolve true quando consegue.
  Future<bool> decideInitialRoute() async {
    await _deviceData.resetIfServerChanged(apiBaseUrl);
    final result = await _authRepository.restoreSession();
    return result is Success;
  }
}
