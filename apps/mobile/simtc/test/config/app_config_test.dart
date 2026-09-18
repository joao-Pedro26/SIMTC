import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('sem --dart-define, aponta para o backend local com o prefixo /api', () {
      expect(AppConfig.apiBaseUrl, 'http://localhost:3001/api');
      expect(AppConfig.environment, 'dev');
      expect(AppConfig.isProduction, isFalse);
    });

    test('a URL base não termina em barra (o ApiClient concatena os paths)', () {
      expect(AppConfig.apiBaseUrl.endsWith('/'), isFalse);
    });
  });
}
