import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/app_release.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/app_update_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/sessions/sessions_screen.dart';
import 'package:simtc/ui/update/update_dialog.dart';
import 'package:simtc/ui/update/update_viewmodel.dart';
import 'package:simtc/utils/result.dart';

import '../../support/fake_assessment_sync_service.dart';

class _MockService extends Mock implements AppUpdateService {}

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockCatalogRepository extends Mock
    implements AssessmentCatalogRepository {}

const int _trintaMb = 30 * 1024 * 1024;

/// Versão publicada usada nos testes: 1.1.0, código 2, 30 MB, duas notas.
AppRelease _release({int minimo = 1, int? sizeBytes = _trintaMb}) => AppRelease(
      versionName: '1.1.0',
      versionCode: 2,
      minSupportedVersionCode: minimo,
      apkUrl:
          'https://x.supabase.co/storage/v1/object/public/app-releases/simtc-1.1.0-2.apk',
      sha256: 'a' * 64,
      sizeBytes: sizeBytes,
      releaseNotes: const ['Correções de sincronização', 'Melhorias no Perfil'],
    );

/// Espera a animação do diálogo e as microtarefas, sem `pumpAndSettle`: o
/// indicador de progresso gira para sempre.
Future<void> assentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() {
    registerFallbackValue(_release());
    registerFallbackValue(File(''));
  });

  late _MockService service;
  late FakeAssessmentSyncService sync;
  late ChangeNotifier conexao;
  late bool wifi;
  late UpdateViewModel vm;

  UpdateViewModel criar() => UpdateViewModel(
        service: service,
        isOnline: () => true,
        isQueueIdle: () => !sync.isSending && sync.queue.isEmpty,
        queueChanges: sync,
        connectivityChanges: conexao,
        isOnWifi: () async => wifi,
      );

  /// Instalada 1; a publicada é [release] (código 2 por padrão).
  void publicada({AppRelease? release}) {
    when(() => service.installedVersionCode()).thenAnswer((_) async => 1);
    when(() => service.fetchLatest())
        .thenAnswer((_) async => Success(release ?? _release()));
  }

  void baixaCom(Future<File> Function(Invocation) resposta) {
    when(() => service.downloadApk(
          any(),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer(resposta);
  }

  void baixaSemFalha() {
    baixaCom((_) async => File('simtc-1.1.0-2.apk'));
    when(() => service.install(any())).thenAnswer((_) async {});
  }

  /// Abre o aviso por um botão, como o Perfil faz, e espera ele aparecer.
  Future<void> abrirAviso(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const Key('abrir'),
              onPressed: () => showUpdateDialog(context, vm),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('abrir')));
    await assentar(tester);
  }

  setUp(() {
    service = _MockService();
    sync = FakeAssessmentSyncService();
    conexao = ChangeNotifier();
    wifi = true;
    vm = criar();
  });

  tearDown(() {
    vm.dispose();
    conexao.dispose();
  });

  group('aviso de versão nova', () {
    testWidgets('mostra título, versão com tamanho, notas e os dois botões',
        (tester) async {
      publicada();
      await vm.checkNow();

      await abrirAviso(tester);

      expect(find.text('Nova versão disponível'), findsOneWidget);
      expect(find.text('Versão 1.1.0 · 30,0 MB'), findsOneWidget);
      expect(find.text('• Correções de sincronização'), findsOneWidget);
      expect(find.text('• Melhorias no Perfil'), findsOneWidget);
      expect(find.text('Depois'), findsOneWidget);
      expect(find.text('Atualizar'), findsOneWidget);
    });

    testWidgets('sem tamanho conhecido, mostra só a versão', (tester) async {
      publicada(release: _release(sizeBytes: null));
      await vm.checkNow();

      await abrirAviso(tester);

      expect(find.text('Versão 1.1.0'), findsOneWidget);
    });

    testWidgets('Depois fecha o aviso sem baixar', (tester) async {
      publicada();
      await vm.checkNow();
      await abrirAviso(tester);

      await tester.tap(find.text('Depois'));
      await assentar(tester);

      expect(find.text('Nova versão disponível'), findsNothing);
      expect(vm.status, UpdateStatus.idle);
      verifyNever(() => service.downloadApk(
            any(),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
          ));
    });

    testWidgets('obrigatória: sem Depois, e o voltar do sistema não fecha',
        (tester) async {
      publicada(release: _release(minimo: 2));
      await vm.checkNow();
      await abrirAviso(tester);

      expect(find.text('Depois'), findsNothing);
      expect(
        find.text('Esta versão do app não é mais compatível. Atualize para '
            'continuar usando.'),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await assentar(tester);

      expect(find.text('Nova versão disponível'), findsOneWidget);
    });
  });

  group('confirmação fora do Wi-Fi', () {
    testWidgets('fora do Wi-Fi, Atualizar pede confirmação; Cancelar não baixa',
        (tester) async {
      wifi = false;
      publicada();
      await vm.checkNow();
      await abrirAviso(tester);

      await tester.tap(find.text('Atualizar'));
      await assentar(tester);

      expect(find.text('Baixar sem Wi-Fi?'), findsOneWidget);
      expect(
        find.text('Você não está no Wi-Fi. A atualização tem 30,0 MB. Baixar '
            'mesmo assim?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await assentar(tester);

      verifyNever(() => service.downloadApk(
            any(),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
          ));
      expect(find.text('Nova versão disponível'), findsOneWidget);
    });

    testWidgets('fora do Wi-Fi, Baixar na confirmação começa o download',
        (tester) async {
      wifi = false;
      publicada();
      baixaSemFalha();
      await vm.checkNow();
      await abrirAviso(tester);

      await tester.tap(find.text('Atualizar'));
      await assentar(tester);
      await tester.tap(find.text('Baixar'));
      await assentar(tester);

      verify(() => service.downloadApk(
            any(),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
          )).called(1);
      verify(() => service.install(any())).called(1);
    });

    testWidgets('no Wi-Fi, Atualizar baixa direto, sem confirmação',
        (tester) async {
      publicada();
      baixaSemFalha();
      await vm.checkNow();
      await abrirAviso(tester);

      await tester.tap(find.text('Atualizar'));
      await assentar(tester);

      expect(find.text('Baixar sem Wi-Fi?'), findsNothing);
      verify(() => service.downloadApk(
            any(),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
          )).called(1);
    });

    testWidgets('sem tamanho conhecido, a confirmação não fala do tamanho',
        (tester) async {
      wifi = false;
      publicada(release: _release(sizeBytes: null));
      await vm.checkNow();
      await abrirAviso(tester);

      await tester.tap(find.text('Atualizar'));
      await assentar(tester);

      expect(
        find.text('Você não está no Wi-Fi. Baixar mesmo assim?'),
        findsOneWidget,
      );
    });

    testWidgets('Tentar de novo também pede confirmação fora do Wi-Fi',
        (tester) async {
      wifi = false;
      publicada();
      baixaCom((_) async =>
          throw const AppUpdateException(AppUpdateFailure.checksum));
      await vm.checkNow();
      await abrirAviso(tester);

      await tester.tap(find.text('Atualizar'));
      await assentar(tester);
      await tester.tap(find.text('Baixar'));
      await assentar(tester);
      expect(find.text('Tentar de novo'), findsOneWidget);

      await tester.tap(find.text('Tentar de novo'));
      await assentar(tester);

      expect(find.text('Baixar sem Wi-Fi?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await assentar(tester);
      verify(() => service.downloadApk(
            any(),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
          )).called(1);
    });
  });

  group('download', () {
    testWidgets('mostra o progresso, e Cancelar volta ao aviso sem erro',
        (tester) async {
      publicada();
      baixaCom((inv) async {
        final onProgress =
            inv.namedArguments[#onProgress] as void Function(double);
        final token = inv.namedArguments[#cancelToken] as CancelToken;
        onProgress(0.5);
        await token.whenCancel;
        throw const AppUpdateException(AppUpdateFailure.download, 'cancelado');
      });
      await vm.checkNow();
      await abrirAviso(tester);

      await tester.tap(find.text('Atualizar'));
      await assentar(tester);

      expect(find.text('Baixando… 50%'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await assentar(tester);

      expect(find.text('Baixando… 50%'), findsNothing);
      expect(find.text('Atualizar'), findsOneWidget);
      expect(vm.errorMessage, isNull);
    });

    testWidgets('erro de checksum mostra a mensagem e Tentar de novo',
        (tester) async {
      publicada();
      baixaCom((_) async =>
          throw const AppUpdateException(AppUpdateFailure.checksum));
      await vm.checkNow();
      await abrirAviso(tester);

      await tester.tap(find.text('Atualizar'));
      await assentar(tester);

      expect(
        find.text(
            'O arquivo baixado está incompleto ou corrompido. Tente de novo.'),
        findsOneWidget,
      );
      expect(find.text('Tentar de novo'), findsOneWidget);
    });
  });

  group('aviso diferido na Home', () {
    late _MockSessionRepository sessionRepository;
    late _MockAuthRepository auth;
    late _MockCatalogRepository catalog;
    late StreamController<List<TrainingSession>> sessoes;
    late ConnectivityService connectivity;

    const consultor = AuthUser(
      id: 'u1',
      name: 'Carla Souza',
      email: 'carla@simtc.com.br',
      role: AppUserRole.consultant,
      consultantId: 'c1',
    );

    setUp(() {
      sessionRepository = _MockSessionRepository();
      auth = _MockAuthRepository();
      catalog = _MockCatalogRepository();
      sessoes = StreamController<List<TrainingSession>>.broadcast();
      connectivity = ConnectivityService();
      when(sessionRepository.watchSessions).thenAnswer((_) => sessoes.stream);
      when(sessionRepository.watchLastSyncedAt)
          .thenAnswer((_) => Stream.value(null));
      when(sessionRepository.syncAll).thenAnswer((_) async => const Success(0));
      when(() => auth.currentUser).thenReturn(consultor);
      when(catalog.sync).thenAnswer((_) async => const Success(7));
    });

    tearDown(() {
      sessoes.close();
      connectivity.dispose();
    });

    /// A Home de verdade, com a ViewModel de atualização no provider.
    Future<void> montarHome(WidgetTester tester) {
      return tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<SessionRepository>.value(value: sessionRepository),
            Provider<AssessmentCatalogRepository>.value(value: catalog),
            ChangeNotifierProvider<AuthRepository>.value(value: auth),
            ChangeNotifierProvider<ConnectivityService>.value(
                value: connectivity),
            ChangeNotifierProvider<UpdateViewModel>.value(value: vm),
          ],
          child: const FormFactorScope(
            formFactor: FormFactor.phone,
            child: MaterialApp(home: SessionsScreen()),
          ),
        ),
      );
    }

    testWidgets(
        'fila esvazia com versão nova: o aviso abre uma vez só, na Home',
        (tester) async {
      publicada();
      sync.setQueue([queuedAssessment('p1')]);
      await montarHome(tester);
      await assentar(tester);

      // A fila ocupada adia a checagem: nada de aviso e nada de rede ainda.
      expect(find.text('Nova versão disponível'), findsNothing);
      verifyNever(() => service.fetchLatest());

      sync.setQueue([]);
      await assentar(tester);

      expect(find.text('Nova versão disponível'), findsOneWidget);
      verify(() => service.fetchLatest()).called(1);
      expect(vm.promptPending, isFalse);

      await tester.tap(find.text('Depois'));
      await assentar(tester);
      expect(find.text('Nova versão disponível'), findsNothing);

      // Outra rodada da fila não reabre o aviso nem checa de novo.
      clearInteractions(service);
      sync.setQueue([queuedAssessment('p2')]);
      sync.setQueue([]);
      await assentar(tester);

      expect(find.text('Nova versão disponível'), findsNothing);
      verifyNever(() => service.fetchLatest());
    });

    testWidgets(
        'a checagem diferida acabou com a Home desmontada: o aviso sai ao montar de novo',
        (tester) async {
      publicada();
      sync.setQueue([queuedAssessment('p1')]);
      await montarHome(tester);
      await assentar(tester);

      await tester.pumpWidget(const SizedBox());
      sync.setQueue([]);
      await assentar(tester);

      // Sem a Home montada, o aviso fica pendente e não abre sozinho.
      expect(find.text('Nova versão disponível'), findsNothing);
      expect(vm.promptPending, isTrue);

      await montarHome(tester);
      await assentar(tester);

      expect(find.text('Nova versão disponível'), findsOneWidget);
      expect(vm.promptPending, isFalse);
    });
  });
}
