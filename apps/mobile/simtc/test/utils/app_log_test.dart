import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/utils/app_log.dart';

void main() {
  final destinoOriginal = appLogSink;
  late List<String> coletadas;

  setUp(() {
    coletadas = [];
    appLogSink = coletadas.add;
  });

  tearDown(() {
    appLogSink = destinoOriginal;
  });

  test('appLog entrega a mensagem ao destino atual', () {
    appLog('Envio da fila falhou: teste');

    expect(coletadas, ['Envio da fila falhou: teste']);
  });
}
