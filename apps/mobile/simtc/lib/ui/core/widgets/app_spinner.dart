import 'package:flutter/material.dart';

/// Indicador circular de espera do DS. O tamanho e a espessura vêm de quem
/// usa, para que cada tela mantenha as suas medidas; sem [color], o indicador
/// segue a cor do tema.
class AppSpinner extends StatelessWidget {
  const AppSpinner({
    super.key,
    this.size = 20,
    this.strokeWidth = 2.5,
    this.color,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: color == null ? null : AlwaysStoppedAnimation<Color>(color!),
      ),
    );
  }
}
