/// Configuração de ambiente, resolvida em tempo de compilação.
///
/// Padrão: a API de produção, também no `flutter run` — por enquanto ela é um
/// ambiente de teste (decisão de 24/10/2026). Para falar com o backend do PC,
/// alcançado pelo aparelho via `adb reverse tcp:3001` (ver README):
/// ```
/// flutter run --dart-define=API_BASE_URL=http://localhost:3001/api
/// ```
/// Trocar de endereço apaga os dados do aparelho na abertura seguinte (ver
/// `DeviceDataService.resetIfServerChanged`).
abstract final class AppConfig {
  /// URL base da API, sempre sem barra no final.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.simtc.com.br/api',
  );
}
