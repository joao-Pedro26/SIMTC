import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';

import 'profile_harness.dart';

/// As medidas da aba Perfil contra os quadros do canvas, com a Inter de
/// verdade: a fonte de teste é mais larga e quebraria "Última sincronização"
/// em duas linhas numa tela de 412. Carregar a fonte vale para o arquivo
/// inteiro, por isso estas medidas moram aqui, longe dos outros testes.
void main() {
  setUpAll(() async {
    final loader = FontLoader('Inter')
      ..addFont(Future.value(
        ByteData.sublistView(File('assets/fonts/Inter.ttf').readAsBytesSync()),
      ));
    await loader.load();
  });

  late ProfileHarness h;

  setUp(() => h = ProfileHarness());
  tearDown(() => h.dispose());

  Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

  testWidgets('celular (quadro "2i"): 20 de recuo, linhas de 56 coladas, '
      '"Sair da conta" de 56 a 24 delas e o texto a 12 dele', (tester) async {
    await h.pump(tester);

    final header = rectOf(tester, find.ancestor(
      of: find.text('Perfil').first,
      matching: find.byType(Container),
    ).first);
    final name = rectOf(tester, find.text('Carla Mendes'));
    expect(name.left, 20);
    expect(name.top, header.bottom + 20);
    final email = rectOf(tester, find.text('carla.mendes@simtreinamentos.com.br'));
    expect(email.top, name.bottom + 4);

    final rows = [
      for (final r in ['role', 'sync', 'cache', 'version'])
        rectOf(tester, ProfileHarness.row(r)),
    ];
    expect(rows.first.top, email.bottom + 20 + 1.5);
    for (final r in rows) {
      expect(r.height, 56);
      expect(r.left, 0);
      expect(r.width, 412);
    }
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].top, rows[i - 1].bottom);
    }
    final icon = rectOf(tester, find.descendant(
      of: ProfileHarness.row('role'),
      matching: find.byType(Icon),
    ));
    expect(icon.left, 20);
    expect(icon.width, 22);
    expect(rectOf(tester, find.text('Perfil de acesso')).left, icon.right + 14);
    expect(rectOf(tester, find.text('Consultor')).right, 412 - 20);

    final button = rectOf(tester, find.byType(AppDangerOutlineButton));
    expect(button.height, 56);
    expect(button.left, 20);
    expect(button.right, 412 - 20);
    expect(button.top, rows.last.bottom + 24);
    expect(
      rectOf(tester, find.textContaining('Sair apaga as sessões')).top,
      button.bottom + 12,
    );
  });

  /// O tablet numa janela de [size]: confere a coluna de [columnLeft] a
  /// [columnRight] (quadros "4k" e "4v").
  Future<void> checkTablet(
    WidgetTester tester,
    Size size, {
    required double columnLeft,
    required double columnRight,
  }) async {
    await h.pump(tester, size: size, formFactor: FormFactor.tablet);

    final title = tester.widget<Text>(find.text('Perfil').first);
    expect(title.style!.fontSize, 24);
    final header = rectOf(tester, find.ancestor(
      of: find.text('Perfil').first,
      matching: find.byType(Container),
    ).first);
    expect(rectOf(tester, find.text('Perfil').first).left, header.left + 24);

    final name = rectOf(tester, find.text('Carla Mendes'));
    expect(tester.widget<Text>(find.text('Carla Mendes')).style!.fontSize, 22);
    expect(name.left, columnLeft);
    expect(name.top, header.bottom + 24);
    final email = rectOf(tester, find.text('carla.mendes@simtreinamentos.com.br'));
    expect(email.top, name.bottom + 5);

    final button = rectOf(tester, find.byType(AppDangerOutlineButton));
    expect(button.height, 48);
    expect(button.right, columnRight);
    expect(button.width, lessThan(240));

    final identity = rectOf(tester, find.byKey(const Key('profile-identity')));
    final rows = [
      for (final r in ['role', 'sync', 'cache', 'version'])
        rectOf(tester, ProfileHarness.row(r)),
    ];
    expect(rows.first.top, identity.bottom + 1.5);
    expect(identity.height, email.bottom - name.top + 22);
    for (final r in rows) {
      expect(r.height, 64);
      expect(r.left, columnLeft);
      expect(r.right, columnRight);
    }
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].top, rows[i - 1].bottom);
    }
    final icon = rectOf(tester, find.descendant(
      of: ProfileHarness.row('role'),
      matching: find.byType(Icon),
    ));
    expect(icon.left, columnLeft);
    expect(icon.width, 23);
    expect(rectOf(tester, find.text('Perfil de acesso')).left, icon.right + 16);
    expect(
      tester.widget<Text>(find.text('Perfil de acesso')).style!.fontSize,
      16,
    );
    expect(rectOf(tester, find.text('Consultor')).right, columnRight);
    expect(tester.widget<Text>(find.text('Consultor')).style!.fontSize, 14.5);

    final note = find.textContaining('Sair apaga as sessões');
    expect(rectOf(tester, note).top, rows.last.bottom + 16);
    expect(tester.widget<Text>(note).style!.fontSize, 13);
  }

  testWidgets('tablet em paisagem (quadro "4k"): navbar na lateral e coluna '
      'de 820 centrada no espaço que sobra', (tester) async {
    // O conteúdo começa em 116 (a navbar lateral): sobram 1164, e a coluna
    // de 820 fica a 172 de cada lado.
    await checkTablet(
      tester,
      const Size(1280, 800),
      columnLeft: 116 + 172,
      columnRight: 116 + 172 + 820,
    );
    expect(
      tester.widget<PillNavBar>(find.byType(PillNavBar)).layout,
      PillNavLayout.rail,
    );
  });

  testWidgets('tablet em retrato (quadro "4v"): pílula na base e a coluna na '
      'largura toda, com 24 de margem', (tester) async {
    await checkTablet(
      tester,
      const Size(800, 1280),
      columnLeft: 24,
      columnRight: 800 - 24,
    );
    expect(
      tester.widget<PillNavBar>(find.byType(PillNavBar)).layout,
      PillNavLayout.tabletBottom,
    );
  });

  testWidgets('tablet numa janela de 1000: a coluna continua com 820, centrada',
      (tester) async {
    // 1000 − 116 = 884 de conteúdo: 32 de cada lado da coluna.
    await checkTablet(
      tester,
      const Size(1000, 800),
      columnLeft: 116 + 32,
      columnRight: 116 + 32 + 820,
    );
  });

  testWidgets('tablet numa janela estreita (tela dividida, 500): a coluna fica '
      'com 24 de margem e nada estoura', (tester) async {
    await h.pump(tester, size: const Size(500, 900), formFactor: FormFactor.tablet);

    expect(tester.takeException(), isNull);
    expect(rectOf(tester, ProfileHarness.row('role')).left, 24);
    expect(rectOf(tester, find.byType(AppDangerOutlineButton)).right, 500 - 24);
  });
}
