import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Celular ou tablet. Decidido uma vez, na abertura, pelo tamanho da tela
/// física — não da janela: em tela dividida o tablet continua sendo tablet
/// (decisão de 21/10/2026).
enum FormFactor { phone, tablet }

/// Os dois cortes da Fase 7.
abstract final class AppBreakpoints {
  /// Lado menor da tela, em dp, a partir do qual o aparelho é tablet.
  static const double tabletShortestSide = 600;

  /// Largura da janela, em dp, a partir da qual lista e detalhe ficam lado a
  /// lado (o tablet em paisagem).
  static const double expandedWidth = 840;
}

/// [logicalScreenSize] é a tela inteira em dp (pixels físicos divididos pela
/// densidade).
FormFactor formFactorFor(Size logicalScreenSize) =>
    logicalScreenSize.shortestSide >= AppBreakpoints.tabletShortestSide
        ? FormFactor.tablet
        : FormFactor.phone;

/// O celular fica travado em retrato; o tablet segue o giro do aparelho em
/// todas as telas, inclusive no checklist (decisão de 21/10/2026). Lista vazia
/// devolve ao sistema todas as orientações.
Future<void> applyOrientationPolicy(FormFactor formFactor) {
  return SystemChrome.setPreferredOrientations(
    formFactor == FormFactor.phone
        ? const [DeviceOrientation.portraitUp]
        : const [],
  );
}

/// Leva o [FormFactor] para a árvore. Sem ele (os testes de tela), vale
/// celular: é o que todas as telas faziam antes da Fase 7.
class FormFactorScope extends InheritedWidget {
  const FormFactorScope({
    super.key,
    required this.formFactor,
    required super.child,
  });

  final FormFactor formFactor;

  static FormFactor of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FormFactorScope>()
          ?.formFactor ??
      FormFactor.phone;

  @override
  bool updateShouldNotify(FormFactorScope oldWidget) =>
      formFactor != oldWidget.formFactor;
}

/// Atalhos para as telas.
extension FormFactorContext on BuildContext {
  bool get isTablet => FormFactorScope.of(this) == FormFactor.tablet;

  /// Tablet com a janela larga o bastante para dois painéis.
  bool get isExpandedLayout =>
      isTablet &&
      MediaQuery.sizeOf(this).width >= AppBreakpoints.expandedWidth;
}
