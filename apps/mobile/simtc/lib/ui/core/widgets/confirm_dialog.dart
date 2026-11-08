import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Diálogo de confirmação do DS: título, mensagem e dois botões. Devolve
/// `true` só se o confirmar foi tocado; cancelar, tocar fora e o voltar do
/// sistema devolvem `false`. Com [destructive], o confirmar fica em vermelho.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  bool destructive = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.dangerInk)
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  // Tocar fora ou o voltar do sistema devolvem null: conta como cancelar.
  return confirmed ?? false;
}
