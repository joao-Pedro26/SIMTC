import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/inline_notice.dart';
import 'package:simtc/ui/core/widgets/status_chip.dart';
import 'package:simtc/ui/session_consultants/consultant_row.dart';

/// A linha numa tela de [width] de largura, dentro de uma lista — como na
/// tela "Consultores".
Future<void> _pump(
  WidgetTester tester,
  Widget row, {
  double width = 412,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: ListView(children: [row])),
    ),
  );
}

const _note =
    'Tem 1 avaliação em andamento. Remover devolve Marcos Vinícius para Pendente.';

void main() {
  testWidgets('mostra o nome, a linha de apoio e o que vai à direita',
      (tester) async {
    await _pump(
      tester,
      const ConsultantRow(
        name: 'Carla Mendes (você)',
        meta: '2 participantes · 1 em andamento',
        trailing: LabelPill(label: 'Responsável', tone: StatusTone.info),
      ),
    );

    expect(find.text('Carla Mendes (você)'), findsOneWidget);
    expect(find.text('2 participantes · 1 em andamento'), findsOneWidget);
    expect(find.text('Responsável'), findsOneWidget);
    // Sem aviso e sem ação, a linha é só o cabeçalho.
    expect(find.byType(InlineNotice), findsNothing);

    // A pastilha fica à direita do nome, com 12 de vão (canvas "3c").
    final name = tester.getRect(find.text('Carla Mendes (você)'));
    final pill = tester.getRect(find.byType(LabelPill));
    expect(pill.left, greaterThan(name.left));
    expect(pill.right, 412 - 20);

    final nameStyle = tester
        .renderObject<RenderParagraph>(find.text('Carla Mendes (você)'))
        .text
        .style;
    expect(nameStyle?.fontSize, 15.5);
    expect(nameStyle?.fontWeight, FontWeight.w600);
  });

  testWidgets('tem o recuo de 15 por 20 e o contorno de 1,5 em cima e embaixo',
      (tester) async {
    await _pump(
      tester,
      const ConsultantRow(
        name: 'Tatiane Souza',
        meta: '2 participantes concluídos',
        trailing: LabelPill(label: 'Consultor', tone: StatusTone.neutral),
      ),
    );

    final row = tester.getRect(find.byType(ConsultantRow));
    final name = tester.getRect(find.text('Tatiane Souza'));
    final meta = tester.getRect(find.text('2 participantes concluídos'));
    expect(row.width, 412);
    expect(name.left - row.left, 20);
    // 1,5 do contorno mais os 15 do recuo.
    expect(name.top - row.top, 16.5);
    expect(row.bottom - meta.bottom, 16.5);
    // 4 entre o nome e a linha de apoio.
    expect(meta.top - name.bottom, 4);

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ConsultantRow),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.surface);
    expect(
      decoration.border,
      const Border(
        top: BorderSide(color: AppColors.border, width: 1.5),
        bottom: BorderSide(color: AppColors.border, width: 1.5),
      ),
    );
  });

  testWidgets('com aviso e ação, empilha os dois sob o nome, com 10 de vão',
      (tester) async {
    await _pump(
      tester,
      ConsultantRow(
        name: 'Rafael Lima',
        meta: '1 participante · 1 em andamento',
        trailing: const LabelPill(label: 'Consultor', tone: StatusTone.neutral),
        note: _note,
        action: AppDangerOutlineButton(
          label: 'Remover da sessão',
          icon: AppIcons.discard,
          compact: true,
          onPressed: () {},
        ),
      ),
    );

    final notice = tester.widget<InlineNotice>(find.byType(InlineNotice));
    expect(notice.message, _note);
    expect(notice.tone, NoticeTone.warning);
    expect(notice.icon, AppIcons.info);

    final meta = tester.getRect(find.text('1 participante · 1 em andamento'));
    final noticeBox = tester.getRect(find.byType(InlineNotice));
    final button = tester.getRect(find.byType(AppDangerOutlineButton));
    final row = tester.getRect(find.byType(ConsultantRow));
    expect(noticeBox.top - meta.bottom, 10);
    expect(button.top - noticeBox.bottom, 10);
    expect(row.bottom - button.bottom, 16.5);
    // O aviso e o botão vão de uma margem à outra.
    expect(noticeBox.left, 20);
    expect(noticeBox.right, 412 - 20);
    expect(button.left, 20);
    expect(button.right, 412 - 20);
  });

  testWidgets('sem a linha de apoio, mostra só o nome', (tester) async {
    await _pump(
      tester,
      ConsultantRow(
        name: 'Diego Barbosa',
        trailing: AppCompactOutlineButton(
          label: 'Adicionar',
          icon: AppIcons.assign,
          onPressed: () {},
        ),
      ),
    );

    expect(find.text('Diego Barbosa'), findsOneWidget);
    // Só o nome e o rótulo do botão.
    expect(find.byType(Text), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('em 360 de largura e com a fonte ampliada, o nome e o e-mail '
      'compridos encolhem com reticências e o botão continua inteiro',
      (tester) async {
    const nome = 'Patrícia Vasconcelos de Albuquerque Figueiredo';
    const email = 'patricia.vasconcelos.albuquerque@simtreinamentos.com.br';

    await _pump(
      tester,
      ConsultantRow(
        name: nome,
        meta: email,
        trailing: AppCompactOutlineButton(
          label: 'Adicionar',
          icon: AppIcons.assign,
          onPressed: () {},
        ),
      ),
      width: 360,
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.renderObject<RenderParagraph>(find.text(nome)).didExceedMaxLines,
      isTrue,
    );
    expect(
      tester.renderObject<RenderParagraph>(find.text(email)).didExceedMaxLines,
      isTrue,
    );
    final button = tester.getRect(find.byType(AppCompactOutlineButton));
    expect(button.right, 360 - 20);
    expect(button.height, 48);
    // O nome vai até 12 antes do botão (o vão do canvas "3c").
    expect(button.left - tester.getRect(find.text(nome)).right, 12);
    expect(
      tester.renderObject<RenderParagraph>(find.text('Adicionar')).didExceedMaxLines,
      isFalse,
    );
  });

  testWidgets('a linha de apoio de quem está na sessão quebra em vez de '
      'encolher: o "em andamento" não some num celular estreito',
      (tester) async {
    const meta = '12 participantes · 3 em andamento';

    Future<RenderParagraph> pumpRow({required bool wraps}) async {
      await _pump(
        tester,
        ConsultantRow(
          name: 'Rafael Lima',
          meta: meta,
          metaWraps: wraps,
          trailing: const LabelPill(label: 'Consultor', tone: StatusTone.neutral),
        ),
        width: 360,
        textScale: 1.3,
      );
      return tester.renderObject<RenderParagraph>(find.text(meta));
    }

    final cut = await pumpRow(wraps: false);
    expect(cut.didExceedMaxLines, isTrue);
    final oneLine = cut.size.height;

    final whole = await pumpRow(wraps: true);
    expect(whole.didExceedMaxLines, isFalse);
    expect(whole.size.height, greaterThan(oneLine));
    expect(tester.takeException(), isNull);
  });

  testWidgets('o aviso comprido quebra em linhas, sem estourar, em 360 de '
      'largura e com a fonte ampliada', (tester) async {
    await _pump(
      tester,
      ConsultantRow(
        name: 'Rafael Lima',
        meta: '3 participantes · 2 em andamento',
        trailing: const LabelPill(label: 'Consultor', tone: StatusTone.neutral),
        note: 'Tem 2 avaliações em andamento. Remover libera esses '
            'participantes para outro consultor.',
        action: AppDangerOutlineButton(
          label: 'Remover da sessão',
          icon: AppIcons.discard,
          compact: true,
          onPressed: () {},
        ),
      ),
      width: 360,
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
    final noticeBox = tester.getRect(find.byType(InlineNotice));
    expect(noticeBox.left, 20);
    expect(noticeBox.right, 360 - 20);
  });
}
