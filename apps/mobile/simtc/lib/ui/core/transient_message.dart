import 'package:flutter/material.dart';

/// Aviso passageiro do DS: agenda, para o quadro seguinte, um `SnackBar` com
/// [message] no `ScaffoldMessenger` da tela. Não faz nada se a tela já saiu.
///
/// Quem chama limpa a mensagem do ViewModel antes de agendar: limpar antes
/// evita reentrância, já que `clear…()` notifica de novo.
void showTransientMessage(State state, String message) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted) return;
    ScaffoldMessenger.of(state.context)
        .showSnackBar(SnackBar(content: Text(message)));
  });
}
