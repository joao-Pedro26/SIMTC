import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';

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
}
