import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Dois toques rápidos no que abre uma tela abrem uma só (Fase 8C).
extension OpenOnce on BuildContext {
  /// Reserva a abertura de uma tela ou janela a partir desta. Falso — e o
  /// toque não faz nada — quando outra abertura já foi pedida e a tela nova
  /// ainda não chegou ao próximo quadro (o go_router só monta a rota nele),
  /// ou quando outra tela já está por cima desta, inclusive enquanto entra.
  bool claimOpen() {
    if (_OpenGate.pending || !(ModalRoute.isCurrentOf(this) ?? true)) {
      return false;
    }
    _OpenGate.hold();
    return true;
  }
}

/// A trava vale até o fim do próximo quadro: aí a rota nova já está no
/// `Navigator`, e o `ModalRoute.isCurrentOf` assume. Ela não depende de a
/// tela abrir — se nada abrir, solta do mesmo jeito.
abstract final class _OpenGate {
  static bool pending = false;

  static void hold() {
    pending = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => pending = false)
      ..ensureVisualUpdate();
  }
}
