import 'dart:async';

import 'package:simtc/utils/app_log.dart';

/// Os logs do app não têm leitor nos testes: só sujavam a saída da suíte
/// (Fase 8D-3). Silenciamos o destino de log do próprio app, sem mexer no
/// `debugPrint` do Flutter.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  appLogSink = (_) {};
  await testMain();
}
