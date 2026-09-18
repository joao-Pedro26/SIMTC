/// Escala de espaçamento do app. Telas e componentes não usam números soltos.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Alvo de toque mínimo no Android — o consultor usa o app com o veículo em movimento
  static const double touchTarget = 48;

  /// Altura dos controles de formulário (campo de texto, botão principal)
  static const double controlHeight = 56;
}

/// Raios de borda do app.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;

  /// Pastilha: chips, navbar flutuante e badges
  static const double pill = 999;
}
