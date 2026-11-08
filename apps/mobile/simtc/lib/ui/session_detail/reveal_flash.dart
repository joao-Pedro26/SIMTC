import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Pisca a linha por cima quando [trigger] muda (vindo da aba Sincronizar, a
/// linha que o consultor tocou). Cada mudança para um número novo pisca de
/// novo; zero nunca pisca.
///
/// Com a animação desligada no sistema, não pisca: a cor some devagar, de uma
/// vez só. A cor fica por cima da linha e não toca nos toques.
class RevealFlash extends StatefulWidget {
  const RevealFlash({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<RevealFlash> createState() => _RevealFlashState();
}

class _RevealFlashState extends State<RevealFlash>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 1200);
  static const double _peak = 0.35;

  // Começa no fim (1): é o repouso, sem cor, e o piscar parte de zero.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: 1,
  );

  @override
  void didUpdateWidget(RevealFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != 0 && widget.trigger != oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Dois pulsos que vão sumindo; sem animação, só o desvanecer.
  double _alphaAt(double t, {required bool reduceMotion}) {
    if (reduceMotion) return _peak * (1 - t);
    return _peak * math.sin(t * 2 * math.pi).abs() * (1 - t / 2);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => ColoredBox(
                color: AppColors.primary.withValues(
                  alpha: _alphaAt(_controller.value, reduceMotion: reduceMotion),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
