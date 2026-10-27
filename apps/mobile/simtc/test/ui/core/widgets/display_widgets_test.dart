import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/theme/app_typography.dart';
import 'package:simtc/ui/core/widgets/admin_dialog.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_top_bar.dart';
import 'package:simtc/ui/core/widgets/company_logo.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
import 'package:simtc/ui/core/widgets/final_score_block.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/core/widgets/session_context_header.dart';
import 'package:simtc/ui/core/widgets/severity_badge.dart';
import 'package:simtc/ui/core/widgets/skeleton.dart';
import 'package:simtc/ui/core/widgets/status_chip.dart';
import 'package:simtc/ui/core/widgets/sync_status_indicator.dart';

import '../../../support/ripple.dart';

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

  testWidgets('LabelPill mostra só o texto, nas cores do tom e com o recuo do '
      'canvas', (tester) async {
    await _pump(
      tester,
      const Row(
        children: [
          LabelPill(label: 'Responsável', tone: StatusTone.info),
          LabelPill(label: 'Consultor', tone: StatusTone.neutral),
        ],
      ),
    );

    expect(find.byType(Icon), findsNothing);

    BoxDecoration boxOf(String label) {
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      return container.decoration! as BoxDecoration;
    }

    Color? inkOf(String label) =>
        tester.renderObject<RenderParagraph>(find.text(label)).text.style?.color;

    expect(boxOf('Responsável').color, AppColors.primarySurface);
    expect(
      boxOf('Responsável').border,
      Border.all(color: AppColors.primary, width: 1.5),
    );
    expect(inkOf('Responsável'), AppColors.primaryDark);
    expect(boxOf('Consultor').color, AppColors.neutralBg);
    expect(
      boxOf('Consultor').border,
      Border.all(color: AppColors.neutralBorder, width: 1.5),
    );
    expect(inkOf('Consultor'), AppColors.neutralInk);

    // Recuo de 10 dos lados e 5 em cima e embaixo, por dentro do contorno
    // de 1,5 (canvas "3c").
    final pill = tester.getRect(find.byType(LabelPill).first);
    final text = tester.getRect(find.text('Responsável'));
    expect(text.left - pill.left, 11.5);
    expect(pill.right - text.right, 11.5);
    expect(text.top - pill.top, 6.5);
    expect(pill.bottom - text.bottom, 6.5);
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
      'FilterChipBar: o chip tem 34 de desenho e 48 de toque; a barra '
      'continua com 54 (Fase 8C)', (tester) async {
    int? selected;
    await _pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: FilterChipBar(
          selectedIndex: 0,
          onSelect: (i) => selected = i,
          items: const [
            FilterChipData(label: 'Todos', count: 8),
            FilterChipData(label: 'Pendentes', count: 3),
          ],
        ),
      ),
    );

    final chip = find.ancestor(
      of: find.text('Pendentes'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(chip).height, 34);
    expect(tester.getSize(find.byType(FilterChipBar)).height, 54);

    // 6 acima do desenho do chip ainda é dele.
    final rect = tester.getRect(chip);
    await tester.tapAt(Offset(rect.center.dx, rect.top - 6));
    expect(selected, 1);

    // Para o leitor de tela e o alvo de toque, o chip tem 48.
    expect(
      tester.getSemantics(find.text('Pendentes')).rect.height,
      48,
    );
    expect(tester.getSemantics(find.text('Todos')),
        isSemantics(isSelected: true, hasSelectedState: true,
            isButton: true, hasTapAction: true, label: 'Todos\n8'));
  });

  testWidgets('FilterChipBar mostra a ondulação do toque (Fase 8C)',
      (tester) async {
    await _pump(
      tester,
      FilterChipBar(
        selectedIndex: 0,
        onSelect: (_) {},
        items: const [
          FilterChipData(label: 'Todos'),
          FilterChipData(label: 'Pendentes'),
        ],
      ),
    );

    expectVisibleRipple(
      tester,
      find.ancestor(of: find.text('Todos'), matching: find.byType(InkWell)),
      background: AppColors.primary,
    );
    expectVisibleRipple(
      tester,
      find.ancestor(of: find.text('Pendentes'), matching: find.byType(InkWell)),
      background: AppColors.surface,
    );
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

  testWidgets('SessionCard mostra a ondulação do toque, comum e destacado '
      '(Fase 8C)', (tester) async {
    Widget card({required bool selected}) => SessionCard(
          companyName: 'Bracell',
          courseName: 'Direção Preventiva',
          meta: 'Hoje · Itabira/MG',
          statusChip: const StatusChip(
            label: 'Planejado',
            icon: AppIcons.sessions,
            tone: StatusTone.info,
          ),
          selected: selected,
          onTap: () {},
        );

    await _pump(tester, card(selected: false));
    expectVisibleRipple(tester, find.byType(InkWell),
        background: AppColors.surface);

    await _pump(tester, card(selected: true));
    expectVisibleRipple(tester, find.byType(InkWell),
        background: AppColors.categoryExpandedBg);
  });

  testWidgets('SessionCard escreve o progresso no peso 500 de verdade (Fase 8C)',
      (tester) async {
    await _pump(
      tester,
      const SessionCard(
        companyName: 'Bracell',
        courseName: 'Direção Preventiva',
        meta: 'Hoje · Itabira/MG',
        statusChip: StatusChip(
          label: 'Em andamento',
          icon: AppIcons.sessions,
          tone: StatusTone.info,
        ),
        progressLabel: '3 de 8 avaliados',
        progressValue: 0.375,
      ),
    );

    expect(tester.widget<Text>(find.text('3 de 8 avaliados')).style,
        AppTypography.progressLabel);
  });

  testWidgets('SessionCard mostra o logo da empresa antes do nome', (tester) async {
    await _pump(
      tester,
      const SessionCard(
        companyName: 'Bracell',
        courseName: 'Direção Preventiva',
        meta: 'Hoje · Itabira/MG',
        leading: CompanyLogo.card(companyName: 'Bracell'),
        statusChip: StatusChip(
          label: 'Planejado',
          icon: AppIcons.sessions,
          tone: StatusTone.info,
        ),
      ),
    );

    final logoX = tester.getTopLeft(find.byType(CompanyLogo)).dx;
    final nameX = tester.getTopLeft(find.text('Bracell')).dx;
    expect(logoX, lessThan(nameX));
  });

  group('CompanyLogo', () {
    testWidgets('sem logo, mostra as iniciais das duas primeiras palavras',
        (tester) async {
      await _pump(tester, const CompanyLogo.card(companyName: 'Bracell Celulose'));

      expect(find.text('BC'), findsOneWidget);
    });

    testWidgets('empresa de uma palavra só usa as duas primeiras letras',
        (tester) async {
      await _pump(tester, const CompanyLogo.card(companyName: 'Bracell'));

      expect(find.text('BR'), findsOneWidget);
    });

    testWidgets('no card tem 44 de lado; no cabeçalho do detalhe, 52',
        (tester) async {
      await _pump(
        tester,
        const Row(
          children: [
            CompanyLogo.card(key: Key('card'), companyName: 'Bracell'),
            CompanyLogo.header(key: Key('header'), companyName: 'Bracell'),
          ],
        ),
      );

      expect(tester.getSize(find.byKey(const Key('card'))), const Size(44, 44));
      expect(tester.getSize(find.byKey(const Key('header'))), const Size(52, 52));
    });

    testWidgets('não tem borda (export de 24/09/2026)', (tester) async {
      await _pump(tester, const CompanyLogo.header(companyName: 'Bracell'));

      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(CompanyLogo),
          matching: find.byType(Container),
        ).first,
      );
      expect((box.decoration! as BoxDecoration).border, isNull);
    });

    group('isSvgLogoUrl', () {
      // O bucket `logos` (companies.service.ts, uploadCompanyLogo) grava a
      // extensão sempre em minúsculas e nunca com query string — o cache
      // busting é pelo timestamp no caminho, não por `?v=`.
      test('reconhece a extensão .svg', () {
        expect(
          isSvgLogoUrl('https://cdn.simtc/logos/emp-1/123.svg'),
          isTrue,
        );
      });

      test('não reconhece raster (png/jpg) como svg', () {
        expect(isSvgLogoUrl('https://cdn.simtc/logos/emp-1/123.png'), isFalse);
        expect(isSvgLogoUrl('https://cdn.simtc/logos/emp-1/123.jpg'), isFalse);
      });
    });
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

  testWidgets(
      'PillNavBar do celular usa os tons do tablet: ativo em primaryDark '
      'sobre primarySurface, inativo em text3 (Fase 8C)', (tester) async {
    await _pump(
      tester,
      PillNavBar(
        currentIndex: 0,
        onSelect: (_) {},
        items: const [
          PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
          PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
        ],
      ),
    );

    expect(tester.widget<Text>(find.text('Sessões')).style!.color,
        AppColors.primaryDark);
    expect(tester.widget<Icon>(find.byIcon(AppIcons.sessions)).color,
        AppColors.primaryDark);
    expect(tester.widget<Text>(find.text('Perfil')).style!.color,
        AppColors.text3);
    expect(tester.widget<Icon>(find.byIcon(AppIcons.profile)).color,
        AppColors.text3);
    expectVisibleRipple(
      tester,
      find.ancestor(of: find.text('Sessões'), matching: find.byType(InkWell)),
      background: AppColors.primarySurface,
    );
  });

  testWidgets('StatusChip mauve escreve em mauveInk (Fase 8C)', (tester) async {
    await _pump(
      tester,
      const StatusChip(
        label: 'Somente teórica',
        icon: AppIcons.theoryOnly,
        tone: StatusTone.mauve,
      ),
    );

    expect(tester.widget<Text>(find.text('Somente teórica')).style!.color,
        AppColors.mauveInk);
    expect(tester.widget<Icon>(find.byIcon(AppIcons.theoryOnly)).color,
        AppColors.mauveInk);
  });

  group('FinalScoreBlock: a pílula (Fase 8C)', () {
    Future<void> pumpBlock(WidgetTester tester, double width) => _pump(
          tester,
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: const FinalScoreBlock(score: 62.5, approved: false),
            ),
          ),
        );

    testWidgets('cabendo, fica à direita do %, embaixo alinhada com ele',
        (tester) async {
      await pumpBlock(tester, 700);

      final percent = tester.getRect(find.text('62,5%'));
      final pill = tester.getRect(find.text('Não recomendado'));
      expect(pill.left, greaterThan(percent.right));
      expect(pill.top, lessThan(percent.bottom));
    });

    testWidgets('sem espaço, desce para baixo do %, sem quebrar o texto',
        (tester) async {
      await pumpBlock(tester, 330);

      final percent = tester.getRect(find.text('62,5%'));
      final pill = tester.getRect(find.text('Não recomendado'));
      expect(pill.top, greaterThan(percent.bottom));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
      'PillNavBar: os rótulos crescem com a fonte do sistema até 1,6× e '
      'param, sem estourar os itens (Fase 8C)', (tester) async {
    await _pump(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: PillNavBar(
          currentIndex: 0,
          onSelect: (_) {},
          items: const [
            PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
            PillNavItem(icon: AppIcons.sync, label: 'Sincronizar'),
            PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
          ],
        ),
      ),
    );

    final label = tester.renderObject<RenderParagraph>(find.text('Sincronizar'));
    expect(label.textScaler.scale(10), 16);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SkeletonListItem anima sem quebrar o layout', (tester) async {
    await _pump(tester, const SkeletonListItem());
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(SkeletonBox), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppTopBar mostra o título e o voltar desempilha a tela',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: AppTopBar(
                        title: 'Detalhe da sessão',
                        trailing: SyncStatusIndicator(),
                      ),
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhe da sessão'), findsOneWidget);
    expect(find.byIcon(AppIcons.syncDone), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhe da sessão'), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('AppTopBar: o título é cabeçalho para o leitor de tela (Fase 8C)',
      (tester) async {
    await _pump(tester, const AppTopBar(title: 'Detalhe da sessão'));

    expect(
      tester.getSemantics(find.text('Detalhe da sessão')),
      isSemantics(label: 'Detalhe da sessão', isHeader: true),
    );
  });

  testWidgets(
      'AdminDialogFrame: o título é cabeçalho e nomeia a janela, para o '
      'leitor de tela anunciá-la ao abrir (Fase 8C)', (tester) async {
    await _pump(
      tester,
      AdminDialogFrame(
        title: 'Adicionar participante',
        subtitle: 'Bracell · Direção Defensiva',
        onClose: () {},
        body: const SizedBox(height: 40),
      ),
    );

    expect(
      tester.getSemantics(find.text('Adicionar participante')),
      isSemantics(
        label: 'Adicionar participante',
        isHeader: true,
        namesRoute: true,
      ),
    );
  });

  testWidgets('AppTopBar põe os atalhos entre o título e o indicador',
      (tester) async {
    var taps = 0;
    await _pump(
      tester,
      AppTopBar(
        title: 'Detalhe da sessão',
        actions: [
          AppIconAction(
            icon: AppIcons.search,
            tooltip: 'Editar dados do treinamento',
            onPressed: () => taps++,
          ),
        ],
        trailing: const SyncStatusIndicator(),
      ),
    );

    final title = tester.getCenter(find.text('Detalhe da sessão')).dx;
    final action = tester.getCenter(find.byType(AppIconAction)).dx;
    final indicator = tester.getCenter(find.byType(SyncStatusIndicator)).dx;
    expect(title, lessThan(action));
    expect(action, lessThan(indicator));

    await tester.tap(find.byTooltip('Editar dados do treinamento'));
    expect(taps, 1);
  });

  group('SessionContextHeader', () {
    testWidgets('mostra as iniciais (sem logo), a empresa e a linha de apoio',
        (tester) async {
      await _pump(
        tester,
        const SessionContextHeader(
          companyName: 'Bracell Celulose',
          subtitle: 'Direção Defensiva — Veículo Pesado',
        ),
      );

      expect(find.text('BC'), findsOneWidget);
      expect(find.text('Bracell Celulose'), findsOneWidget);
      expect(find.text('Direção Defensiva — Veículo Pesado'), findsOneWidget);
    });

    testWidgets('com título, a primeira linha é ele, e as iniciais continuam '
        'sendo as da empresa', (tester) async {
      await _pump(
        tester,
        const SessionContextHeader(
          companyName: 'Bracell Celulose',
          title: 'Bracell Celulose · 12 set',
          subtitle: '5 participantes · 3 consultores',
        ),
      );

      expect(find.text('BC'), findsOneWidget);
      expect(find.text('Bracell Celulose · 12 set'), findsOneWidget);
      expect(find.text('Bracell Celulose'), findsNothing);
      expect(find.text('5 participantes · 3 consultores'), findsOneWidget);
    });

    testWidgets('apagada usa o fundo da tela; a normal, o da superfície',
        (tester) async {
      Color? background() {
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(SessionContextHeader),
                matching: find.byType(Container),
              )
              .first,
        );
        return (container.decoration! as BoxDecoration).color;
      }

      await _pump(
        tester,
        const SessionContextHeader(companyName: 'Bracell', subtitle: 'Curso'),
      );
      expect(background(), AppColors.surface);

      await _pump(
        tester,
        const SessionContextHeader(
          companyName: 'Bracell',
          subtitle: 'Curso',
          muted: true,
        ),
      );
      expect(background(), AppColors.background);
    });

    testWidgets('a normal tem as medidas dos quadros "3a" e "3c": 12 de recuo, '
        'logo de 40, empresa em 14 e 2 até a linha de apoio (Fase 8C)',
        (tester) async {
      await _pump(
        tester,
        const Column(
          children: [
            SessionContextHeader(companyName: 'Bracell', subtitle: 'Curso'),
          ],
        ),
      );

      expect(tester.getSize(find.byType(CompanyLogo)), const Size(40, 40));
      expect(tester.widget<Text>(find.text('Bracell')).style!.fontSize, 14);
      expect(
        tester.getRect(find.text('Curso')).top -
            tester.getRect(find.text('Bracell')).bottom,
        2,
      );
      expect(tester.getSize(find.byType(SessionContextHeader)).height,
          12 + 40 + 12 + 1);
    });

    testWidgets('a espaçosa tem as do quadro "3b": 14 de recuo, logo de 44, '
        'empresa em 15 e 3 até a linha de apoio (Fase 8C)', (tester) async {
      await _pump(
        tester,
        const Column(
          children: [
            SessionContextHeader(
              companyName: 'Bracell',
              subtitle: 'Curso',
              spacious: true,
            ),
          ],
        ),
      );

      expect(tester.getSize(find.byType(CompanyLogo)), const Size(44, 44));
      expect(tester.widget<Text>(find.text('Bracell')).style!.fontSize, 15);
      expect(
        tester.getRect(find.text('Curso')).top -
            tester.getRect(find.text('Bracell')).bottom,
        3,
      );
      expect(tester.getSize(find.byType(SessionContextHeader)).height,
          14 + 44 + 14 + 1);
    });

    testWidgets('nome e apoio compridos encolhem com reticências, sem estourar',
        (tester) async {
      const nome = 'Transportes Vale Norte Sociedade Anônima do Brasil';
      const apoio = 'Direção Defensiva — Veículo Pesado · Reciclagem anual';

      await _pump(
        tester,
        const SizedBox(
          width: 320,
          child: SessionContextHeader(companyName: nome, subtitle: apoio),
        ),
      );

      expect(
        tester.renderObject<RenderParagraph>(find.text(nome)).didExceedMaxLines,
        isTrue,
      );
      expect(
        tester.renderObject<RenderParagraph>(find.text(apoio)).didExceedMaxLines,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('SessionCard destacado tem a mesma altura e o texto no mesmo '
      'lugar do card comum', (tester) async {
    Future<(Rect, Rect)> measure(bool selected) async {
      // Numa lista, como na Home: solto no corpo do Scaffold, o card
      // esticaria até o fim da tela e a altura nunca mudaria.
      await _pump(
        tester,
        ListView(
          children: [
            SessionCard(
              companyName: 'Bracell',
              courseName: 'Direção Defensiva',
              meta: 'Itabira/MG · 07:30',
              statusChip: const SizedBox(height: 24, width: 80),
              selected: selected,
            ),
          ],
        ),
      );
      return (
        tester.getRect(find.byType(SessionCard)),
        tester.getRect(find.text('Bracell')),
      );
    }

    final (plainCard, plainText) = await measure(false);
    final (selectedCard, selectedText) = await measure(true);
    expect(selectedCard.height, closeTo(plainCard.height, 0.001));
    expect(selectedText.topLeft.dx, closeTo(plainText.topLeft.dx, 0.001));
    expect(selectedText.topLeft.dy, closeTo(plainText.topLeft.dy, 0.001));
  });
}
