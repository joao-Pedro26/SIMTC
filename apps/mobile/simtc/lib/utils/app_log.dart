import 'package:flutter/foundation.dart';

/// Destino das mensagens de log do app. Em produção vai para o `debugPrint`;
/// os testes trocam por outro destino para não sujar a saída da suíte.
typedef AppLogSink = void Function(String message);

/// Destino atual dos logs do app.
AppLogSink appLogSink = (message) => debugPrint(message);

/// Registra uma mensagem de log no destino atual (`appLogSink`).
void appLog(String message) => appLogSink(message);
