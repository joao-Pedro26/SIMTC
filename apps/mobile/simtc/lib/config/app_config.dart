/// Configuração de ambiente, resolvida em tempo de compilação.
///
/// Desenvolvimento (padrão): o app fala com o backend rodando no PC, alcançado
/// pelo aparelho via `adb reverse tcp:3001` (ver README).
///
/// Produção:
/// ```
/// flutter build apk --release \
///   --dart-define=API_BASE_URL=https://api.simtc.com.br/api \
///   --dart-define=APP_ENV=prod
/// ```
abstract final class AppConfig {
  /// URL base da API, sempre sem barra no final.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001/api',
  );

  /// Nome do ambiente: `dev` ou `prod`.
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static bool get isProduction => environment == 'prod';
}
