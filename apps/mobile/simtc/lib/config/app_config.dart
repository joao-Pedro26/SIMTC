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

  /// Onde o app procura a versão mais recente: o `latest.json` do bucket
  /// público `app-releases`, no Supabase de produção. Para testar contra o
  /// bucket do dev, passe `--dart-define=UPDATE_MANIFEST_URL=...`.
  static const String updateManifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue:
        'https://gohdttoyatgapamigaep.supabase.co/storage/v1/object/public/app-releases/latest.json',
  );

  /// Em build de debug a checagem de atualização fica desligada (o `flutter
  /// run` e os testes não devem baixar nada). Para ligar:
  /// `--dart-define=CHECK_UPDATES_IN_DEBUG=true`.
  static const bool checkUpdatesInDebug =
      bool.fromEnvironment('CHECK_UPDATES_IN_DEBUG');
}
