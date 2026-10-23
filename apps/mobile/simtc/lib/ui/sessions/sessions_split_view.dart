import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_nav_bar.dart';
import '../session_detail/session_detail_screen.dart';
import 'sessions_screen.dart';

/// Lista de sessões e detalhe no tablet — uma página só para `/home` e
/// `/sessions/:id`, que o router reaproveita entre as duas rotas.
///
/// - Paisagem (quadros "4c" e "4d"): navbar lateral, lista de 392 à esquerda
///   e o detalhe da [selectedSessionId] à direita. Sem sessão escolhida, um
///   aviso no lugar do detalhe (decisão de 21/10/2026).
/// - Retrato (quadro "4e"): uma tela por vez. Com sessão escolhida, o
///   detalhe ocupa a tela, com o voltar; a lista continua montada embaixo,
///   escondida, e volta do jeito que estava.
///
/// Girar o aparelho não perde nada: a lista e o detalhe têm `GlobalKey`, e
/// mudam de lugar na árvore sem recriar o estado (a ViewModel, o filtro, a
/// rolagem).
class SessionsSplitView extends StatefulWidget {
  const SessionsSplitView({super.key, this.selectedSessionId});

  final String? selectedSessionId;

  @override
  State<SessionsSplitView> createState() => _SessionsSplitViewState();
}

class _SessionsSplitViewState extends State<SessionsSplitView> {
  /// Largura da lista em paisagem.
  static const double listWidth = 392;

  final GlobalKey _listKey = GlobalKey(debugLabel: 'lista-de-sessoes');

  /// Uma chave por sessão aberta: trocar de sessão cria um detalhe novo; a
  /// mesma sessão, girando, reaproveita o que já existe.
  GlobalKey? _detailKey;
  String? _detailKeyId;

  GlobalKey _detailKeyFor(String sessionId) {
    if (_detailKeyId != sessionId) {
      _detailKeyId = sessionId;
      _detailKey = GlobalKey(debugLabel: 'detalhe-$sessionId');
    }
    return _detailKey!;
  }

  void _open(String sessionId) =>
      context.go(AppRoutes.sessionDetail(sessionId));

  void _backToList() => context.go(AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    final expanded = context.isExpandedLayout;
    final selected = widget.selectedSessionId;

    final list = SessionsScreen(
      key: _listKey,
      embedded: expanded,
      selectedSessionId: expanded ? selected : null,
      onOpenSession: _open,
    );

    final Widget body;
    if (expanded) {
      body = _buildTwoPanes(list, selected);
    } else if (selected == null) {
      body = list;
    } else {
      body = Stack(
        fit: StackFit.expand,
        children: [
          Offstage(child: TickerMode(enabled: false, child: list)),
          SessionDetailScreen(
            key: _detailKeyFor(selected),
            sessionId: selected,
            onBack: _backToList,
          ),
        ],
      );
    }

    // Com uma sessão aberta, o voltar do Android fecha a sessão em vez de
    // fechar o app: em retrato volta para a lista; em paisagem, tira a
    // seleção.
    return PopScope(
      canPop: selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToList();
      },
      child: body,
    );
  }

  Widget _buildTwoPanes(Widget list, String? selected) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: TabletNavFrame(
          current: AppTab.sessions,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: listWidth, child: list),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.border,
              ),
              Expanded(
                child: selected == null
                    ? const _NoSessionSelected()
                    : SessionDetailScreen(
                        key: _detailKeyFor(selected),
                        sessionId: selected,
                        embedded: true,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O lado direito antes de escolher uma sessão (o canvas não desenha este
/// estado; aprovado em 21/10/2026).
class _NoSessionSelected extends StatelessWidget {
  const _NoSessionSelected();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('no-session-selected'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.sessions, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Escolha uma sessão na lista',
              style: AppTypography.cardTitle.copyWith(color: AppColors.text3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
