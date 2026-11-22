import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/confirm_dialog.dart';
import '../profile/profile_labels.dart';
import 'update_viewmodel.dart';

/// Checagem da abertura do app: se achar uma versão nova, mostra o aviso.
///
/// Chamada pela Home depois do primeiro frame. Sem `UpdateViewModel` no
/// `MultiProvider` (os testes das telas), não faz nada.
Future<void> maybePromptUpdate(BuildContext context) async {
  final viewModel = context.read<UpdateViewModel?>();
  if (viewModel == null) return;

  final found = await viewModel.checkOnOpen();
  if (!found || !context.mounted) return;
  await showUpdateDialog(context, viewModel);
}

/// O aviso diferido: a Home o abre quando a checagem adiada (fila ociosa)
/// achou versão nova. Sem nada pendente, não faz nada.
Future<void> showPendingUpdatePrompt(BuildContext context) async {
  final viewModel = context.read<UpdateViewModel?>();
  if (viewModel == null || !viewModel.promptPending) return;

  viewModel.markPromptShown();
  await showUpdateDialog(context, viewModel);
}

/// "Verificar atualização" do Perfil: mostra o aviso se há versão nova e, se
/// não há, diz o que aconteceu.
Future<void> checkUpdateManually(BuildContext context) async {
  final viewModel = context.read<UpdateViewModel?>();
  if (viewModel == null) return;

  final messenger = ScaffoldMessenger.of(context);
  await viewModel.checkNow();
  if (!context.mounted) return;

  if (viewModel.hasUpdate) {
    await showUpdateDialog(context, viewModel);
    return;
  }
  final failed = viewModel.status == UpdateStatus.failed;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        failed
            ? viewModel.errorMessage ??
                'Não foi possível verificar atualizações.'
            : 'O app já está na versão mais recente.',
      ),
    ),
  );
}

/// O aviso de versão nova. Não fecha ao tocar fora: durante o download e na
/// atualização obrigatória, nem o voltar do Android o fecha.
Future<void> showUpdateDialog(BuildContext context, UpdateViewModel viewModel) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(viewModel: viewModel),
  );
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.viewModel});

  final UpdateViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final locked = viewModel.mandatory ||
            viewModel.status == UpdateStatus.downloading;
        return PopScope(
          canPop: !locked,
          child: AlertDialog(
            title: Text(viewModel.hasUpdate
                ? 'Nova versão disponível'
                : 'Atualização do app'),
            content: SingleChildScrollView(child: _content()),
            actions: _actions(context),
          ),
        );
      },
    );
  }

  /// "Atualizar" e "Tentar de novo": fora do Wi-Fi, pede confirmação antes de
  /// gastar dados móveis. Só baixa se o usuário confirmar.
  Future<void> _atualizar(BuildContext context) async {
    if (viewModel.confirmNotOnWifi) {
      final size = viewModel.release?.sizeBytes;
      final confirmado = await showConfirmDialog(
        context,
        title: 'Baixar sem Wi-Fi?',
        message: 'Você não está no Wi-Fi.'
            '${size == null ? '' : ' A atualização tem ${sizeLabel(size)}.'}'
            ' Baixar mesmo assim?',
        confirmLabel: 'Baixar',
        destructive: false,
      );
      if (!confirmado) return;
    }
    await viewModel.startUpdate();
  }

  Widget _content() {
    final release = viewModel.release;
    final status = viewModel.status;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (release != null) ...[
          Text(
            'Versão ${release.versionName}'
            '${release.sizeBytes == null ? '' : ' · ${sizeLabel(release.sizeBytes!)}'}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (release.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final note in release.releaseNotes) Text('• $note'),
          ],
          if (viewModel.mandatory) ...[
            const SizedBox(height: 12),
            const Text(
              'Esta versão do app não é mais compatível. Atualize para '
              'continuar usando.',
            ),
          ],
        ],
        if (status == UpdateStatus.downloading) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: viewModel.progress > 0 ? viewModel.progress : null,
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          Text('Baixando… ${(viewModel.progress * 100).round()}%'),
        ],
        if (status == UpdateStatus.installing) ...[
          const SizedBox(height: 16),
          const Text(
            'O instalador do Android foi aberto. Toque em Instalar para '
            'concluir. Se ele pedir permissão para instalar apps de fontes '
            'desconhecidas, libere e toque em “Instalar de novo”.',
          ),
        ],
        if (status == UpdateStatus.failed) ...[
          if (release != null) const SizedBox(height: 16),
          Text(
            viewModel.errorMessage ?? 'Não foi possível concluir.',
            style: const TextStyle(color: AppColors.dangerInk),
          ),
        ],
      ],
    );
  }

  List<Widget> _actions(BuildContext context) {
    void close() {
      viewModel.dismiss();
      Navigator.of(context).pop();
    }

    final canClose = !viewModel.mandatory;
    return switch (viewModel.status) {
      UpdateStatus.available => [
          if (canClose) TextButton(onPressed: close, child: const Text('Depois')),
          FilledButton(
            onPressed: () => _atualizar(context),
            child: const Text('Atualizar'),
          ),
        ],
      UpdateStatus.downloading => [
          TextButton(
            onPressed: viewModel.cancelDownload,
            child: const Text('Cancelar'),
          ),
        ],
      UpdateStatus.installing => [
          if (canClose) TextButton(onPressed: close, child: const Text('Fechar')),
          FilledButton(
            onPressed: viewModel.startUpdate,
            child: const Text('Instalar de novo'),
          ),
        ],
      UpdateStatus.failed => [
          if (canClose || !viewModel.hasUpdate)
            TextButton(onPressed: close, child: const Text('Fechar')),
          if (viewModel.hasUpdate)
            FilledButton(
              onPressed: () => _atualizar(context),
              child: const Text('Tentar de novo'),
            ),
        ],
      _ => [TextButton(onPressed: close, child: const Text('Fechar'))],
    };
  }
}
