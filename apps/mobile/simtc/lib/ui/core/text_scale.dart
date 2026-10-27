import 'package:flutter/widgets.dart';

/// A fonte do sistema em 1,3× ou mais — o "grande" do Android (Fase 8C).
const double largeTextScale = 1.3;

extension TextScaleContext on BuildContext {
  /// Quanto a fonte do sistema amplia o texto (1 é o normal).
  double get textScale => MediaQuery.textScalerOf(this).scale(1);

  /// A fonte do sistema em [largeTextScale] ou mais.
  bool get isLargeText => textScale >= largeTextScale;
}
