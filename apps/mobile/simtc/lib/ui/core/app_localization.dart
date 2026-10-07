import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Idioma do app: português do Brasil, fixo.
///
/// Os textos das telas são escritos direto em português; isto aqui cobre o que
/// o próprio Material desenha — o calendário de "Dados do treinamento", o menu
/// de copiar/colar dos campos e os rótulos de acessibilidade. Sem estes
/// delegates, o Flutter mostra tudo isso em inglês.
abstract final class AppLocalization {
  static const Locale locale = Locale('pt', 'BR');

  static const List<Locale> supportedLocales = [locale];

  static const List<LocalizationsDelegate<dynamic>> delegates =
      GlobalMaterialLocalizations.delegates;
}
