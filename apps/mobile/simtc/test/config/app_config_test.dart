import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('sem --dart-define, aponta para a API de produção com o prefixo /api',
        () {
      expect(AppConfig.apiBaseUrl, 'https://api.simtc.com.br/api');
    });

    test('a URL base não termina em barra (o ApiClient concatena os paths)', () {
      expect(AppConfig.apiBaseUrl.endsWith('/'), isFalse);
    });
  });
}
