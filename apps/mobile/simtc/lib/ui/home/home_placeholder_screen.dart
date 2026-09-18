import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';

/// Tela provisória depois do login — substituída pela lista de sessões na Fase 2.
///
/// Existe para fechar o fluxo desta fase: entrar, ver quem está logado e sair.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('SIMTC')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Olá, ${user?.name ?? ''}', style: AppTypography.screenTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(user?.email ?? '', style: AppTypography.body),
            const SizedBox(height: AppSpacing.xs),
            Text(
              user?.isAdmin == true ? 'Perfil: administrador' : 'Perfil: consultor',
              style: AppTypography.meta,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Consultor vinculado: ${user?.consultantId ?? '—'}',
                style: AppTypography.meta),
            const Spacer(),
            AppSecondaryButton(
              label: 'Sair',
              onPressed: () => context.read<AuthRepository>().logout(),
            ),
          ],
        ),
      ),
    );
  }
}
