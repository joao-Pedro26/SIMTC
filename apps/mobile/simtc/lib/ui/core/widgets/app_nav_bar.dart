import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/services/assessment_sync_service.dart';
import '../../../router.dart';
import '../form_factor.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import 'pill_nav_bar.dart';

/// As abas que têm tela. "Perfil" ainda não tem (Fase 8).
enum AppTab { sessions, sync }

/// Em volta do `Scaffold` de uma aba: no tablet com a pílula na base, o aviso
/// passageiro (SnackBar) flutua acima dela, em vez de cobri-la (decisão de
/// 23/10/2026). O `Theme` fica sempre na árvore — girar não pode recriar o
/// `Scaffold` de dentro.
class TabSnackBarArea extends StatelessWidget {
  const TabSnackBarArea({super.key, required this.child});

  final Widget child;

  /// Folga entre o aviso e a pílula.
  static const double gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!context.isTablet || context.isExpandedLayout) {
      return Theme(data: theme, child: child);
    }

    final side = TabletNavFrame.sideFor(MediaQuery.sizeOf(context).width);
    return Theme(
      data: theme.copyWith(
        snackBarTheme: theme.snackBarTheme.copyWith(
          behavior: SnackBarBehavior.floating,
          insetPadding: EdgeInsets.fromLTRB(
            side,
            0,
            side,
            TabletNavFrame.bottomInset + gap,
          ),
        ),
      ),
      child: child,
    );
  }
}

/// A navbar do app, com os três itens e o destino de cada um — a mesma nas
/// abas Sessões e Sincronizar, em qualquer formato.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.current,
    this.layout = PillNavLayout.phone,
  });

  final AppTab current;
  final PillNavLayout layout;

  @override
  Widget build(BuildContext context) {
    // O mesmo número do indicador do cabeçalho: a fila de envio.
    final queued = context.watch<AssessmentSyncService?>()?.queue.length ?? 0;

    return PillNavBar(
      currentIndex: current.index,
      layout: layout,
      items: [
        const PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
        PillNavItem(
          icon: AppIcons.sync,
          label: 'Sincronizar',
          shortLabel: 'Sincr.',
          badgeCount: queued,
        ),
        const PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
      ],
      onSelect: (index) {
        if (index == AppTab.sessions.index && current != AppTab.sessions) {
          context.go(AppRoutes.home);
        }
        if (index == AppTab.sync.index && current != AppTab.sync) {
          context.go(AppRoutes.sync);
        }
        if (index == 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Disponível em breve.')),
          );
        }
      },
    );
  }
}

/// Moldura das abas no tablet: a navbar flutua por cima do conteúdo, que
/// recua para não ficar embaixo dela.
///
/// - Paisagem (dois painéis): coluna na lateral esquerda, a 14 da borda e
///   centrada na altura; o conteúdo começa em 116 (quadro "4c").
/// - Retrato: pílula na base, a 16 do fundo e a 120 das laterais; o conteúdo
///   termina 100 acima do fundo (quadro "4u"). Numa janela estreita (tela
///   dividida), a pílula volta aos 16 de recuo do celular.
class TabletNavFrame extends StatelessWidget {
  const TabletNavFrame({
    super.key,
    required this.current,
    required this.child,
  });

  final AppTab current;
  final Widget child;

  static const double railInset = 116;
  static const double bottomInset = 100;

  /// Distância da navbar à borda da tela: a lateral fica a 14 da esquerda;
  /// a pílula, a 16 do fundo e a 120 das laterais.
  static const double railLeft = AppSpacing.md + 2;
  static const double bottomSide = 120;

  /// Recuo da pílula às laterais numa janela de [width]: 120, ou os 16 do
  /// celular numa janela mais estreita que 600 (tela dividida).
  static double sideFor(double width) =>
      width >= AppBreakpoints.tabletShortestSide ? bottomSide : AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    if (context.isExpandedLayout) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: railInset),
            child: child,
          ),
          Positioned(
            left: railLeft,
            top: 0,
            bottom: 0,
            child: Center(
              widthFactor: 1,
              child: AppNavBar(current: current, layout: PillNavLayout.rail),
            ),
          ),
        ],
      );
    }

    final side = sideFor(MediaQuery.sizeOf(context).width);
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: bottomInset),
          child: child,
        ),
        Positioned(
          left: side,
          right: side,
          bottom: AppSpacing.lg,
          child: AppNavBar(current: current, layout: PillNavLayout.tabletBottom),
        ),
      ],
    );
  }
}
