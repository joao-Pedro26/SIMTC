import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/profile/profile_labels.dart';
import 'package:simtc/ui/profile/profile_screen.dart';

import '../../support/a11y.dart';
import '../../support/fake_assessment_sync_service.dart';
import 'profile_harness.dart';

void main() {
  late ProfileHarness h;

  setUp(() => h = ProfileHarness());
  tearDown(() => h.dispose());

  Finder row(String name) => ProfileHarness.row(name);

  /// Um quadro e o fim da animação do diálogo, sem esperar o resto assentar
  /// (o indicador de carregamento gira para sempre).
  Future<void> closeDialog(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('mostra quem entrou e as quatro linhas, sem "Empresa"',
      (tester) async {
    await h.pump(tester, lastSyncedAt: DateTime(2026, 10, 24, 7, 12));

    expect(find.text('Carla Mendes'), findsOneWidget);
    expect(find.text('carla.mendes@simtreinamentos.com.br'), findsOneWidget);
    expect(
      find.descendant(of: row('role'), matching: find.text('Consultor')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('sync'), matching: find.text('hoje 07:12')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('cache'), matching: find.text('18,4 MB')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('version'), matching: find.text('1.0.0 (1)')),
      findsOneWidget,
    );
    expect(find.text('Empresa'), findsNothing);
    expect(
      find.text(
        'Sair apaga as sessões baixadas neste aparelho. As avaliações na fila '
        'ficam guardadas e são enviadas quando você entrar de novo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('o administrador vê "Administrador", e quem nunca enviou, '
      '"Nenhum envio"', (tester) async {
    when(() => h.auth.currentUser).thenReturn(const AuthUser(
      id: 'user-2',
      name: 'Bruno Lima',
      email: 'bruno@simtc.com.br',
      role: AppUserRole.admin,
    ));
    await h.pump(tester);

    expect(
      find.descendant(of: row('role'), matching: find.text('Administrador')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('sync'), matching: find.text('Nenhum envio')),
      findsOneWidget,
    );
  });

  testWidgets('tudo o que se toca tem 48 e rótulo (Fase 8C)', (tester) async {
    await h.pump(tester);

    await expectAccessibleTargets(tester);
  });

  testWidgets('a navbar marca o Perfil', (tester) async {
    await h.pump(tester);

    expect(tester.widget<PillNavBar>(find.byType(PillNavBar)).currentIndex, 2);
    // O título da aba é cabeçalho para o leitor de tela (Fase 8C).
    expect(tester.getSemantics(find.text('Perfil').first),
        isSemantics(isHeader: true));
  });

  testWidgets(
      'no tablet, girar com a limpeza em andamento não recria a tela: a linha '
      'continua girando e o fim da limpeza chega', (tester) async {
    final gate = Completer<void>();
    when(() => h.deviceData.clearDownloaded()).thenAnswer((_) => gate.future);
    await h.pump(tester, size: const Size(1280, 800), formFactor: FormFactor.tablet);
    final state = tester.state(find.byType(ProfileScreen));

    await tester.tap(row('cache'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar'));
    await closeDialog(tester);
    for (final size in const [Size(800, 1280), Size(1280, 800), Size(800, 1280)]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(tester.state(find.byType(ProfileScreen)), same(state));
      expect(
        find.descendant(
          of: row('cache'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    }

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Cache local limpo.'), findsOneWidget);
  });

  testWidgets('o voltar do Android leva para Sessões', (tester) async {
    await h.pump(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  group('limpar cache local', () {
    testWidgets('pergunta antes; confirmando, limpa, mede de novo e avisa',
        (tester) async {
      await h.pump(tester);

      await tester.tap(row('cache'));
      await tester.pumpAndSettle();
      expect(find.text('Limpar cache local?'), findsOneWidget);
      expect(
        find.text(
          'As sessões, os participantes, o catálogo e os logos baixados serão '
          'apagados e baixados de novo quando você abrir as sessões. A fila e '
          'as avaliações iniciadas não são apagadas.',
        ),
        findsOneWidget,
      );

      when(() => h.deviceData.downloadedBytes())
          .thenAnswer((_) async => 36 * 1024);
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();

      verify(() => h.deviceData.clearDownloaded()).called(1);
      expect(find.text('Cache local limpo.'), findsOneWidget);
      expect(
        find.descendant(of: row('cache'), matching: find.text('36 KB')),
        findsOneWidget,
      );
    });

    testWidgets('cancelar não limpa', (tester) async {
      await h.pump(tester);

      await tester.tap(row('cache'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => h.deviceData.clearDownloaded());
    });

    testWidgets('enquanto limpa, a linha gira, não aceita outro toque e o '
        '"Sair da conta" espera', (tester) async {
      final gate = Completer<void>();
      when(() => h.deviceData.clearDownloaded()).thenAnswer((_) => gate.future);
      await h.pump(tester);

      await tester.tap(row('cache'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpar'));
      await closeDialog(tester);

      expect(
        find.descendant(
          of: row('cache'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(row('cache'));
      await closeDialog(tester);
      expect(find.text('Limpar cache local?'), findsNothing);
      expect(
        tester
            .widget<AppDangerOutlineButton>(find.byType(AppDangerOutlineButton))
            .onPressed,
        isNull,
      );

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a falha avisa', (tester) async {
      when(() => h.deviceData.clearDownloaded()).thenThrow(Exception('disco'));
      await h.pump(tester);

      await tester.tap(row('cache'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível limpar o cache. Tente de novo.'),
        findsOneWidget,
      );
    });

    testWidgets('sem conexão, fica desativado e diz por quê', (tester) async {
      await h.goOffline();
      await h.pump(tester);

      expect(
        find.descendant(
          of: row('cache'),
          matching: find.text('Disponível quando houver conexão'),
        ),
        findsOneWidget,
      );
      await tester.tap(row('cache'));
      await tester.pumpAndSettle();

      expect(find.text('Limpar cache local?'), findsNothing);
    });
  });

  group('sair da conta', () {
    testWidgets(
        'dois toques rápidos abrem uma confirmação só, mesmo enquanto as '
        'avaliações iniciadas são contadas (Fase 8C)', (tester) async {
      await h.pump(tester);

      await tester.tap(find.text('Sair da conta'));
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsOneWidget);
    });

    testWidgets('sem fila nem rascunho, a confirmação é a simples; '
        'confirmando, sai', (tester) async {
      await h.pump(tester);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsOneWidget);
      expect(
        find.text(logoutMessage(queued: 0, drafts: 0, offline: false)),
        findsOneWidget,
      );
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      verify(() => h.auth.logout()).called(1);
    });

    testWidgets('com fila e rascunho, sem rede, a confirmação avisa o que '
        'fica guardado e que entrar de novo precisa de rede', (tester) async {
      await h.goOffline();
      await h.seedDraft();
      await h.seedDraft(owner: 'outra-pessoa', participantId: 'tp-8');
      await h.pump(tester, queue: [
        queuedAssessment('tp-1'),
        queuedAssessment('tp-2'),
      ]);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(
        find.text(logoutMessage(queued: 2, drafts: 1, offline: true)),
        findsOneWidget,
      );
    });

    testWidgets('cancelar não sai', (tester) async {
      await h.pump(tester);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => h.auth.logout());
    });

    testWidgets('enquanto sai, o botão gira e o "Limpar cache local" espera',
        (tester) async {
      final gate = Completer<void>();
      when(() => h.auth.logout()).thenAnswer((_) => gate.future);
      await h.pump(tester);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await closeDialog(tester);

      expect(
        tester
            .widget<AppDangerOutlineButton>(find.byType(AppDangerOutlineButton))
            .isLoading,
        isTrue,
      );
      await tester.tap(row('cache'));
      await closeDialog(tester);
      expect(find.text('Limpar cache local?'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a falha avisa', (tester) async {
      when(() => h.auth.logout()).thenThrow(Exception('keystore'));
      await h.pump(tester);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível sair. Tente de novo.'), findsOneWidget);
    });
  });
}
