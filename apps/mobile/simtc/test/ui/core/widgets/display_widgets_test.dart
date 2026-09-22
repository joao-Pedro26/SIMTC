import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/core/widgets/severity_badge.dart';
import 'package:simtc/ui/core/widgets/skeleton.dart';
import 'package:simtc/ui/core/widgets/status_chip.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('StatusChip mostra ícone e texto juntos, nunca só cor', (tester) async {
    await _pump(
      tester,
      const StatusChip(
        label: 'Aprovado',
        icon: AppIcons.approved,
        tone: StatusTone.success,
      ),
    );

    expect(find.text('Aprovado'), findsOneWidget);
    expect(find.byIcon(AppIcons.approved), findsOneWidget);
  });

  testWidgets('SeverityBadge usa os rótulos literais B, PM e M', (tester) async {
    await _pump(
      tester,
      const Row(
        children: [
          SeverityBadge(severity: Severity.b),
          SeverityBadge(severity: Severity.pm),
          SeverityBadge(severity: Severity.m),
        ],
      ),
    );

    expect(find.text('B'), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.textContaining('Melhorar'), findsNothing);
  });

  testWidgets('FilterChipBar devolve o índice tocado', (tester) async {
    int? selected;
    await _pump(
      tester,
      FilterChipBar(
        selectedIndex: 0,
        onSelect: (i) => selected = i,
        items: const [
          FilterChipData(label: 'Todos', count: 8),
          FilterChipData(label: 'Pendentes', count: 3),
        ],
      ),
    );

    await tester.tap(find.text('Pendentes'));
    expect(selected, 1);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets(
      'quando selectedIndex muda por fora (ex.: destaque por scroll manual), '
      'a barra rola até o chip ficar visível', (tester) async {
    // 360dp — Android de entrada, onde os três chips com contadores não
    // cabem de uma vez.
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selectedIndex = 0;
    late StateSetter setInnerState;

    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          setInnerState = setState;
          return FilterChipBar(
            selectedIndex: selectedIndex,
            onSelect: (i) => setState(() => selectedIndex = i),
            items: const [
              FilterChipData(label: 'Hoje', count: 2),
              FilterChipData(label: 'Próximos 7 dias', count: 5),
              FilterChipData(label: 'Concluídas', count: 12),
            ],
          );
        },
      ),
    );

    final viewportWidth = tester.getSize(find.byType(FilterChipBar)).width;

    // Antes de qualquer mudança, "Concluídas" começa fora da faixa visível —
    // confirma que o cenário do teste é o real (barra mais larga que a tela).
    final beforeRect =
        tester.getRect(find.widgetWithText(InkWell, 'Concluídas'));
    expect(beforeRect.right, greaterThan(viewportWidth));

    // Muda `selectedIndex` sem passar por nenhum toque no chip — o
    // equivalente ao que `sessions_screen.dart` faz quando o scroll manual
    // destaca a seção mais visível.
    setInnerState(() => selectedIndex = 2);
    await tester.pumpAndSettle();

    final afterRect =
        tester.getRect(find.widgetWithText(InkWell, 'Concluídas'));
    expect(afterRect.left, greaterThanOrEqualTo(0));
    expect(afterRect.right, lessThanOrEqualTo(viewportWidth));
  });

  testWidgets('SessionCard mostra os dados, responde ao toque e esconde a barra sem progresso',
      (tester) async {
    var taps = 0;
    await _pump(
      tester,
      SessionCard(
        companyName: 'Bracell',
        courseName: 'Direção Preventiva',
        meta: 'Hoje · Itabira/MG',
        statusChip: const StatusChip(
          label: 'Planejado',
          icon: AppIcons.sessions,
          tone: StatusTone.info,
        ),
        onTap: () => taps++,
      ),
    );

    expect(find.text('Bracell'), findsOneWidget);
    expect(find.text('Direção Preventiva'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.text('Bracell'));
    expect(taps, 1);
  });

  testWidgets('PillNavBar marca o item ativo, mostra o badge e devolve o toque',
      (tester) async {
    int? selected;
    await _pump(
      tester,
      PillNavBar(
        currentIndex: 0,
        onSelect: (i) => selected = i,
        items: const [
          PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
          PillNavItem(icon: AppIcons.sync, label: 'Sincronizar', badgeCount: 3),
          PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
        ],
      ),
    );

    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Perfil'));
    expect(selected, 2);
  });

  testWidgets('SkeletonListItem anima sem quebrar o layout', (tester) async {
    await _pump(tester, const SkeletonListItem());
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(SkeletonBox), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
