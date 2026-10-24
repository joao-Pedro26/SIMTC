import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/add_participant/add_participant_screen.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/date_labels.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_top_bar.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
import 'package:simtc/ui/sessions/sessions_screen.dart';
import 'package:simtc/ui/sessions/sessions_split_view.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Repositório de verdade com a gravação da marcação presa num portão: o
/// teste decide quando ela termina.
class _GatedAssessmentRepository extends AssessmentRepository {
  _GatedAssessmentRepository({required super.database});

  Completer<void>? gate;

  @override
  Future<List<LocalAssessmentItem>> mark({
    required String localAssessmentId,
    required String infractionId,
    required String infractionNoteId,
  }) async {
    await gate?.future;
    return super.mark(
      localAssessmentId: localAssessmentId,
      infractionId: infractionId,
      infractionNoteId: infractionNoteId,
    );
  }
}

const _landscape = Size(1280, 800);
const _portrait = Size(800, 1280);

void main() {
  late _MockApiClient api;
  late _MockAuthRepository auth;
  late AppDatabase db;
  late _GatedAssessmentRepository assessments;
  late ConnectivityService connectivity;

  setUp(() async {
    api = _MockApiClient();
    // O servidor nunca responde: tudo sai do banco local.
    const offline = ApiException(message: 'sem rede', isNetworkError: true);
    when(() => api.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
        .thenThrow(offline);
    when(() => api.get<Map<String, dynamic>>(any(),
        queryParameters: any(named: 'queryParameters'))).thenThrow(offline);
    when(() => api.get<List<dynamic>>(any(),
        queryParameters: any(named: 'queryParameters'))).thenThrow(offline);
    auth = _MockAuthRepository();
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => auth.currentUser).thenReturn(const AuthUser(
      id: 'user-1',
      name: 'Carla Souza',
      email: 'carla@simtc.com.br',
      role: AppUserRole.consultant,
      consultantId: 'c-eu',
    ));
    // Ver `checklist_screen_test.dart`: fechar os streams na hora evita o
    // timer pendente do drift no fim do teste.
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    assessments = _GatedAssessmentRepository(database: db);
    connectivity = ConnectivityService();

    final now = DateTime.now();
    for (final (id, company) in [
      ('sess-1', 'Bracell'),
      ('sess-2', 'Transportes Vale Norte'),
    ]) {
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: id,
              companyName: company,
              courseName: 'Direção Defensiva',
              city: 'Itabira',
              state: 'MG',
              status: 'EM_ANDAMENTO',
              date: Value(now),
              participantsSyncedAt: Value(now),
              cachedAt: now,
            ),
          );
    }
    await db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-1',
            sessionId: 'sess-1',
            name: 'Ana Paula Ribeiro',
            cpf: '042.118.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'EM_AVALIACAO',
            assignedConsultantId: const Value('c-eu'),
            cachedAt: now,
          ),
        );
    await db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-2',
            sessionId: 'sess-1',
            name: 'Carlos Eduardo Nunes',
            cpf: '118.042.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'PENDENTE',
            cachedAt: now,
          ),
        );
    await db.into(db.assessmentCategories).insert(
          AssessmentCategoriesCompanion.insert(
            id: 'cat-1',
            code: 'CV',
            name: 'Controle do Veículo',
            order: 1,
          ),
        );
    for (final (id, description) in [
      ('inf-1', 'Excesso de velocidade'),
      ('inf-2', 'Freada brusca'),
    ]) {
      await db.into(db.infractions).insert(
            InfractionsCompanion.insert(
              id: id,
              categoryId: 'cat-1',
              description: description,
              order: id == 'inf-1' ? 1 : 2,
            ),
          );
      for (final (note, deduction) in [('B', 1), ('PM', 3), ('M', 5)]) {
        await db.into(db.infractionNotes).insert(
              InfractionNotesCompanion.insert(
                id: '$id-$note',
                infractionId: id,
                noteType: note,
                deduction: deduction,
              ),
            );
      }
    }
  });

  tearDown(() async {
    await db.close();
    connectivity.dispose();
  });

  void screen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
  }

  /// O app no tablet, pelas rotas reais, aberto em [location].
  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    required String location,
    Size size = _landscape,
  }) async {
    screen(tester, size);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = createRouter(auth, initialLocation: location);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(
            value: SessionRepository(apiClient: api, database: db),
          ),
          Provider<ParticipantRepository>.value(
            value: ParticipantRepository(apiClient: api, database: db),
          ),
          Provider<SessionConsultantRepository>.value(
            value: SessionConsultantRepository(apiClient: api, database: db),
          ),
          Provider<AssessmentCatalogRepository>.value(
            value: AssessmentCatalogRepository(apiClient: api, database: db),
          ),
          Provider<AssessmentRepository>.value(value: assessments),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: FormFactorScope(
          formFactor: FormFactor.tablet,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await settle(tester);
    return router;
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> rotate(WidgetTester tester, Size size) async {
    screen(tester, size);
    await settle(tester);
  }

  Finder card(String company) =>
      find.ancestor(of: find.text(company), matching: find.byType(SessionCard));

  int detailFilter(WidgetTester tester) => tester
      .widget<FilterChipBar>(
        find.descendant(
          of: find.byType(SessionDetailScreen),
          matching: find.byType(FilterChipBar),
        ),
      )
      .selectedIndex;

  testWidgets('paisagem sem sessão escolhida: navbar lateral, lista de 392 e '
      'o aviso no lugar do detalhe', (tester) async {
    await pumpApp(tester, location: AppRoutes.home);

    expect(tester.widget<PillNavBar>(find.byType(PillNavBar)).layout,
        PillNavLayout.rail);
    expect(tester.getRect(find.byType(SessionsScreen)),
        const Rect.fromLTWH(116, 0, 392, 800));
    expect(find.text('Escolha uma sessão na lista'), findsOneWidget);
    expect(find.byType(SessionDetailScreen), findsNothing);
  });

  testWidgets('tocar no card abre o detalhe ao lado, destaca o card e a lista '
      'continua a mesma', (tester) async {
    final router = await pumpApp(tester, location: AppRoutes.home);
    final listState = tester.state(find.byType(SessionsScreen));

    await tester.tap(card('Bracell'));
    await settle(tester);

    expect(location(router), AppRoutes.sessionDetail('sess-1'));
    expect(find.text('Escolha uma sessão na lista'), findsNothing);
    final detail = tester.widget<SessionDetailScreen>(
      find.byType(SessionDetailScreen),
    );
    expect(detail.sessionId, 'sess-1');
    expect(detail.embedded, isTrue);
    expect(tester.getRect(find.byType(SessionDetailScreen)).left, 116 + 392 + 1);
    expect(tester.widget<SessionCard>(card('Bracell')).selected, isTrue);
    expect(identical(tester.state(find.byType(SessionsScreen)), listState), isTrue);
  });

  testWidgets('trocar de sessão abre outro detalhe, do zero', (tester) async {
    await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
    final first = tester.state(find.byType(SessionDetailScreen));

    await tester.tap(card('Transportes Vale Norte'));
    await settle(tester);

    expect(
      tester.widget<SessionDetailScreen>(find.byType(SessionDetailScreen)).sessionId,
      'sess-2',
    );
    expect(identical(tester.state(find.byType(SessionDetailScreen)), first), isFalse);
    expect(tester.widget<SessionCard>(card('Transportes Vale Norte')).selected, isTrue);
    expect(tester.widget<SessionCard>(card('Bracell')).selected, isFalse);
  });

  testWidgets('girar com a sessão aberta: em retrato o detalhe ocupa a tela, '
      'com o voltar; o detalhe e o filtro atravessam vários giros',
      (tester) async {
    await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
    await tester.tap(find.descendant(
      of: find.byType(SessionDetailScreen),
      matching: find.text('Pendentes'),
    ));
    await settle(tester);
    final filter = detailFilter(tester);
    final detailState = tester.state(find.byType(SessionDetailScreen));
    final listState = tester.state(find.byType(SessionsScreen));

    for (var i = 0; i < 3; i++) {
      await rotate(tester, _portrait);
      expect(find.byType(AppTopBar), findsOneWidget);
      expect(tester.getRect(find.byType(SessionDetailScreen)),
          const Rect.fromLTWH(0, 0, 800, 1280));
      expect(tester.widget<SessionDetailScreen>(
        find.byType(SessionDetailScreen),
      ).embedded, isFalse);
      expect(find.byType(PillNavBar), findsNothing);
      expect(identical(tester.state(find.byType(SessionDetailScreen)), detailState),
          isTrue);
      expect(detailFilter(tester), filter);

      await rotate(tester, _landscape);
      expect(find.byType(AppTopBar), findsNothing);
      expect(identical(tester.state(find.byType(SessionDetailScreen)), detailState),
          isTrue);
      expect(identical(tester.state(find.byType(SessionsScreen)), listState),
          isTrue);
      expect(detailFilter(tester), filter);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('em retrato, o voltar da barra leva à lista, que volta como '
      'estava', (tester) async {
    final router = await pumpApp(
      tester,
      location: AppRoutes.home,
      size: _portrait,
    );
    final listState = tester.state(find.byType(SessionsScreen));
    expect(tester.widget<PillNavBar>(find.byType(PillNavBar)).layout,
        PillNavLayout.tabletBottom);

    await tester.tap(card('Bracell'));
    await settle(tester);
    expect(location(router), AppRoutes.sessionDetail('sess-1'));
    expect(find.byType(AppTopBar), findsOneWidget);
    // A lista fica montada embaixo, escondida.
    expect(find.byType(SessionsScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await settle(tester);

    expect(location(router), AppRoutes.home);
    expect(find.byType(SessionDetailScreen), findsNothing);
    expect(identical(tester.state(find.byType(SessionsScreen)), listState), isTrue);
  });

  testWidgets('o voltar do Android fecha a sessão: em retrato volta à lista, '
      'em paisagem tira a seleção', (tester) async {
    final router = await pumpApp(
      tester,
      location: AppRoutes.sessionDetail('sess-1'),
      size: _portrait,
    );

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(location(router), AppRoutes.home);
    expect(find.byType(SessionDetailScreen), findsNothing);

    await rotate(tester, _landscape);
    await tester.tap(card('Bracell'));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(location(router), AppRoutes.home);
    expect(find.text('Escolha uma sessão na lista'), findsOneWidget);
  });

  testWidgets('a lista e o detalhe são uma página só: ir de uma rota à outra '
      'não empilha nada', (tester) async {
    final router = await pumpApp(tester, location: AppRoutes.home);
    final split = tester.state(find.byType(SessionsSplitView));

    router.go(AppRoutes.sessionDetail('sess-1'));
    await settle(tester);
    router.go(AppRoutes.home);
    await settle(tester);

    expect(identical(tester.state(find.byType(SessionsSplitView)), split), isTrue);
    expect(find.byType(SessionsSplitView), findsOneWidget);
  });

  group('checklist (o que reprova a fase)', () {
    // A linha inteira da infração (`infraction-<id>`): no tablet, os botões
    // B/PM/M ficam ao lado da descrição, fora da coluna dela.
    Finder note(String infraction, String note) => find.descendant(
          of: find.ancestor(
            of: find.text(infraction),
            matching: find.byWidgetPredicate((w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('infraction-')),
          ),
          matching: find.text(note),
        );

    testWidgets('girar várias vezes no meio do checklist não perde nenhuma '
        'marcação, nem a que ainda está gravando', (tester) async {
      await assessments.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
        ownerUserId: 'user-1',
        consultantId: 'c-eu',
      );
      await pumpApp(
        tester,
        location: AppRoutes.participantChecklist('sess-1', 'tp-1'),
      );
      final checklist = tester.state(find.byType(ChecklistScreen));

      await tester.tap(note('Excesso de velocidade', 'PM'));
      await settle(tester);

      // A segunda marcação fica gravando enquanto o tablet gira.
      assessments.gate = Completer<void>();
      await tester.tap(note('Freada brusca', 'M'));
      await tester.pump();

      for (final size in [_portrait, _landscape, _portrait, _landscape]) {
        await rotate(tester, size);
        expect(identical(tester.state(find.byType(ChecklistScreen)), checklist),
            isTrue, reason: 'o checklist não pode ser recriado ao girar');
      }

      assessments.gate!.complete();
      await settle(tester);

      final saved = await assessments.loadItems(
        (await assessments.findByParticipant('tp-1'))!.id,
      );
      expect(
        {for (final item in saved) item.infractionId: item.infractionNoteId},
        {'inf-1': 'inf-1-PM', 'inf-2': 'inf-2-M'},
      );
      await rotate(tester, _portrait);
      // A tela mostra o que está gravado: a categoria vale 10 (dois itens de
      // até 5), e PM (3) + M (5) deixam 2 — 20%.
      expect(find.text('20,0%'), findsWidgets);
    });
  });

  group('janelas de admin', () {
    setUp(() {
      when(() => auth.currentUser).thenReturn(const AuthUser(
        id: 'user-1',
        name: 'Carla Souza',
        email: 'carla@simtc.com.br',
        role: AppUserRole.admin,
        consultantId: 'c-eu',
      ));
    });

    Finder dialog() => find.byKey(const Key('admin-dialog'));

    bool highlighted(WidgetTester tester, String tooltip) => tester
        .widget<AppIconAction>(find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(AppIconAction),
        ))
        .highlighted;

    Finder nameField() => find.descendant(
          of: find.byKey(const Key('campo-nome')),
          matching: find.byType(EditableText),
        );

    testWidgets(
        'em paisagem, "Adicionar participante" abre numa janela de 560 ancorada '
        'à direita, por cima do lado a lado, com o botão marcado (quadro "4l")',
        (tester) async {
      await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
      expect(highlighted(tester, 'Adicionar participante'), isFalse);

      await tester.tap(find.byTooltip('Adicionar participante'));
      await settle(tester);

      expect(find.byType(AddParticipantScreen), findsOneWidget);
      final rect = tester.getRect(dialog());
      expect(rect.width, 560);
      expect(rect.right, 1280 - 40);
      expect(rect.top, 80);
      expect(rect.height, lessThanOrEqualTo(640));
      expect(find.byType(SessionsScreen), findsOneWidget, reason: 'o lado a lado fica embaixo');
      expect(find.text('Escolha uma sessão na lista'), findsNothing);
      expect(highlighted(tester, 'Adicionar participante'), isTrue);
      expect(find.text('Bracell · Direção Defensiva · ${dayMonthLabel(DateTime.now())}'),
          findsOneWidget, reason: 'a empresa e a sessão no subtítulo');
      final cta = find.widgetWithText(AppCtaButton, 'Adicionar participante');
      expect(tester.getSize(cta).height, 52);
      expect(tester.getTopRight(cta).dx, rect.right - 24);
      expect(
        tester.getCenter(find.text('Salvar e adicionar outro')).dy,
        tester.getCenter(cta).dy,
        reason: 'o rodapé é uma linha só',
      );
    });

    testWidgets(
        'em retrato, a janela fica no centro, com 640 de largura (quadro "4w")',
        (tester) async {
      await pumpApp(tester, location: AppRoutes.addParticipant('sess-1'), size: _portrait);

      final rect = tester.getRect(dialog());
      expect(rect.width, 640);
      expect(rect.center.dx, 400);
      expect(rect.center.dy, 640);
    });

    testWidgets(
        'girar várias vezes com o formulário preenchido não perde o que foi '
        'digitado', (tester) async {
      await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
      await tester.tap(find.byTooltip('Adicionar participante'));
      await settle(tester);
      final form = tester.state(find.byType(AddParticipantScreen));

      await tester.enterText(nameField(), 'Fernanda Lopes Meireles');
      await tester.pump();

      for (final size in [_portrait, _landscape, _portrait, _landscape]) {
        await rotate(tester, size);
        expect(identical(tester.state(find.byType(AddParticipantScreen)), form), isTrue,
            reason: 'a janela não pode ser recriada ao girar');
        expect(find.text('Fernanda Lopes Meireles'), findsOneWidget);
      }
      expect(highlighted(tester, 'Adicionar participante'), isTrue,
          reason: 'o botão continua marcado depois de girar');
    });

    testWidgets(
        'tocar no fundo é o mesmo que o X: com algo preenchido, pergunta antes; '
        'descartando, a janela fecha e o botão desmarca', (tester) async {
      final router = await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
      await tester.tap(find.byTooltip('Adicionar participante'));
      await settle(tester);
      await tester.enterText(nameField(), 'Fernanda');
      await tester.pump();

      await tester.tapAt(const Offset(200, 400));
      await settle(tester);

      expect(find.text('Descartar o que foi preenchido?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await settle(tester);

      expect(dialog(), findsNothing);
      expect(location(router), AppRoutes.sessionDetail('sess-1'));
      expect(highlighted(tester, 'Adicionar participante'), isFalse);
    });

    testWidgets('sem nada preenchido, tocar no fundo fecha a janela', (tester) async {
      final router = await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
      await tester.tap(find.byTooltip('Adicionar participante'));
      await settle(tester);

      await tester.tapAt(const Offset(200, 400));
      await settle(tester);

      expect(dialog(), findsNothing);
      expect(location(router), AppRoutes.sessionDetail('sess-1'));
    });

    testWidgets(
        'com o teclado aberto em paisagem, a janela encolhe acima dele e nada '
        'estoura', (tester) async {
      await pumpApp(tester, location: AppRoutes.addParticipant('sess-1'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      addTearDown(tester.view.resetViewInsets);
      await settle(tester);

      final rect = tester.getRect(dialog());
      expect(rect.bottom, lessThanOrEqualTo(800 - 400));
      expect(tester.takeException(), isNull);
    });
  });
}

/// `pumpAndSettle` com teto: a Home anima o skeleton até a lista chegar.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
