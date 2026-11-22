import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/app_release.dart';
import 'package:simtc/data/services/app_update_service.dart';
import 'package:simtc/ui/update/update_viewmodel.dart';
import 'package:simtc/utils/result.dart';

import '../../support/fake_assessment_sync_service.dart';

class _MockService extends Mock implements AppUpdateService {}

const String _mensagemFilaOcupada =
    'Aguarde o envio das avaliações terminar e tente de novo.';

/// Versão publicada usada nos testes: código 2, mínima 1 (opcional).
AppRelease _release({int code = 2, int minimo = 1}) => AppRelease(
      versionName: '1.1.0',
      versionCode: code,
      minSupportedVersionCode: minimo,
      apkUrl: 'https://x.supabase.co/storage/v1/object/public/app-releases/simtc-1.1.0-2.apk',
      sha256: 'a' * 64,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_release());
    registerFallbackValue(File(''));
  });

  late _MockService service;
  late FakeAssessmentSyncService sync;
  late bool online;
  late bool wifi;
  late UpdateViewModel vm;
  var vmDescartado = false;

  UpdateViewModel criar({bool enabled = true}) => UpdateViewModel(
        service: service,
        isOnline: () => online,
        isQueueIdle: () => !sync.isSending && sync.queue.isEmpty,
        queueChanges: sync,
        isOnWifi: () async => wifi,
        enabled: enabled,
      );

  /// Instalada `instalada`, publicada `_release(code: 2, minimo: minimo)`.
  void publicada({int instalada = 1, int minimo = 1, int code = 2}) {
    when(() => service.installedVersionCode())
        .thenAnswer((_) async => instalada);
    when(() => service.fetchLatest())
        .thenAnswer((_) async => Success(_release(code: code, minimo: minimo)));
  }

  /// Deixa a versão nova carregada no ViewModel pela checagem manual.
  Future<void> carregarVersaoNova({bool obrigatoria = false}) async {
    publicada(instalada: 1, minimo: obrigatoria ? 2 : 1);
    await vm.checkNow();
  }

  setUp(() {
    service = _MockService();
    sync = FakeAssessmentSyncService();
    online = true;
    wifi = true;
    vmDescartado = false;
    vm = criar();
  });

  tearDown(() {
    if (!vmDescartado) vm.dispose();
  });

  group('checagem da abertura', () {
    test('versão nova → available e checkOnOpen devolve true', () async {
      publicada();

      final achou = await vm.checkOnOpen();

      expect(achou, isTrue);
      expect(vm.status, UpdateStatus.available);
      expect(vm.hasUpdate, isTrue);
      expect(vm.release?.versionCode, 2);
    });

    test('versão obrigatória → mandatory true', () async {
      publicada(instalada: 1, minimo: 2);

      await vm.checkOnOpen();

      expect(vm.mandatory, isTrue);
    });

    test('versão igual → upToDate e checkOnOpen devolve false', () async {
      publicada(instalada: 2, code: 2);

      final achou = await vm.checkOnOpen();

      expect(achou, isFalse);
      expect(vm.status, UpdateStatus.upToDate);
      expect(vm.hasUpdate, isFalse);
    });

    test('Failure → idle e sem errorMessage', () async {
      when(() => service.installedVersionCode()).thenAnswer((_) async => 1);
      when(() => service.fetchLatest())
          .thenAnswer((_) async => Failure(Exception('sem rede')));

      final achou = await vm.checkOnOpen();

      expect(achou, isFalse);
      expect(vm.status, UpdateStatus.idle);
      expect(vm.errorMessage, isNull);
    });

    test('enabled false → nem chama o service', () async {
      vm.dispose();
      vmDescartado = true;
      vm = criar(enabled: false);

      final achou = await vm.checkOnOpen();

      expect(achou, isFalse);
      verifyNever(() => service.installedVersionCode());
      verifyNever(() => service.fetchLatest());
    });

    test('segunda checkOnOpen → false sem chamar o service', () async {
      publicada();
      await vm.checkOnOpen();
      clearInteractions(service);

      final segunda = await vm.checkOnOpen();

      expect(segunda, isFalse);
      verifyNever(() => service.fetchLatest());
    });

    test('offline → false sem chamar o service', () async {
      publicada();
      online = false;

      final achou = await vm.checkOnOpen();

      expect(achou, isFalse);
      verifyNever(() => service.fetchLatest());
    });

    test('fila com envio no ar → false e service não chamado', () async {
      publicada();
      sync.setQueue([], sendingIds: {'local-p1'});

      final achou = await vm.checkOnOpen();

      expect(achou, isFalse);
      verifyNever(() => service.fetchLatest());
    });

    test('fila não vazia → false e service não chamado', () async {
      publicada();
      sync.setQueue([queuedAssessment('p1')]);

      final achou = await vm.checkOnOpen();

      expect(achou, isFalse);
      verifyNever(() => service.fetchLatest());
    });

    test('fila esvazia depois → checa uma vez e liga promptPending', () async {
      publicada();
      sync.setQueue([queuedAssessment('p1')]);
      await vm.checkOnOpen();
      expect(vm.promptPending, isFalse);

      sync.setQueue([]);
      await pumpEventQueue();

      verify(() => service.fetchLatest()).called(1);
      expect(vm.promptPending, isTrue);
    });

    test('markPromptShown desliga promptPending', () async {
      publicada();
      sync.setQueue([queuedAssessment('p1')]);
      await vm.checkOnOpen();
      sync.setQueue([]);
      await pumpEventQueue();
      expect(vm.promptPending, isTrue);

      vm.markPromptShown();

      expect(vm.promptPending, isFalse);
    });

    test('fila esvazia sem versão nova → promptPending false', () async {
      publicada(instalada: 2, code: 2);
      sync.setQueue([queuedAssessment('p1')]);
      await vm.checkOnOpen();

      sync.setQueue([]);
      await pumpEventQueue();

      verify(() => service.fetchLatest()).called(1);
      expect(vm.promptPending, isFalse);
      expect(vm.status, UpdateStatus.upToDate);
    });

    test('fila esvazia offline → fica pendente até a próxima notificação', () async {
      publicada();
      sync.setQueue([queuedAssessment('p1')]);
      await vm.checkOnOpen();

      online = false;
      sync.setQueue([]);
      await pumpEventQueue();
      verifyNever(() => service.fetchLatest());
      expect(vm.promptPending, isFalse);

      online = true;
      sync.setQueue([]);
      await pumpEventQueue();
      verify(() => service.fetchLatest()).called(1);
      expect(vm.promptPending, isTrue);
    });

    test('confirmNotOnWifi true fora do wi-fi e false no wi-fi', () async {
      publicada();
      wifi = false;
      await vm.checkOnOpen();
      expect(vm.confirmNotOnWifi, isTrue);

      vm.dispose();
      vmDescartado = true;
      vm = criar();
      publicada();
      wifi = true;
      await vm.checkOnOpen();
      expect(vm.confirmNotOnWifi, isFalse);
    });

    test('confirmNotOnWifi vale também para a checagem diferida', () async {
      publicada();
      wifi = false;
      sync.setQueue([queuedAssessment('p1')]);
      await vm.checkOnOpen();

      sync.setQueue([]);
      await pumpEventQueue();

      expect(vm.promptPending, isTrue);
      expect(vm.confirmNotOnWifi, isTrue);
    });

    test('dispose com checagem pendente não lança nem chama o service', () async {
      publicada();
      sync.setQueue([queuedAssessment('p1')]);
      await vm.checkOnOpen();

      vm.dispose();
      vmDescartado = true;
      sync.setQueue([]);
      await pumpEventQueue();

      verifyNever(() => service.fetchLatest());
    });
  });

  group('checkNow', () {
    test('fila ocupada → failed com a mensagem e sem chamar o service', () async {
      publicada();
      sync.setQueue([queuedAssessment('p1')]);

      await vm.checkNow();

      expect(vm.status, UpdateStatus.failed);
      expect(vm.errorMessage, _mensagemFilaOcupada);
      verifyNever(() => service.fetchLatest());
    });

    test('Failure → failed com mensagem', () async {
      when(() => service.installedVersionCode()).thenAnswer((_) async => 1);
      when(() => service.fetchLatest())
          .thenAnswer((_) async => Failure(Exception('sem rede')));

      await vm.checkNow();

      expect(vm.status, UpdateStatus.failed);
      expect(vm.errorMessage,
          'Não foi possível verificar atualizações. Tente de novo mais tarde.');
    });

    test('offline → failed com a mensagem de sem conexão', () async {
      online = false;

      await vm.checkNow();

      expect(vm.status, UpdateStatus.failed);
      expect(vm.errorMessage,
          'Sem conexão. Conecte-se à internet para verificar.');
      verifyNever(() => service.fetchLatest());
    });
  });

  group('startUpdate', () {
    test('com progresso → downloading com progress, depois installing', () async {
      await carregarVersaoNova();
      final pendente = Completer<File>();
      void Function(double)? progresso;
      when(() => service.downloadApk(
            any(),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((inv) {
        progresso = inv.namedArguments[#onProgress] as void Function(double)?;
        return pendente.future;
      });
      when(() => service.install(any())).thenAnswer((_) async {});

      final atualizando = vm.startUpdate();
      progresso!(0.5);

      expect(vm.status, UpdateStatus.downloading);
      expect(vm.progress, 0.5);

      pendente.complete(File('simtc-1.1.0-2.apk'));
      await atualizando;

      expect(vm.status, UpdateStatus.installing);
      verify(() => service.install(any())).called(1);
    });

    test('checksum → failed com a mensagem de arquivo corrompido', () async {
      await carregarVersaoNova();
      when(() => service.downloadApk(
            any(),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
          )).thenThrow(const AppUpdateException(AppUpdateFailure.checksum));

      await vm.startUpdate();

      expect(vm.status, UpdateStatus.failed);
      expect(vm.errorMessage,
          'O arquivo baixado está incompleto ou corrompido. Tente de novo.');
    });

    test('duas chamadas seguidas → downloadApk chamado uma vez', () async {
      await carregarVersaoNova();
      final pendente = Completer<File>();
      when(() => service.downloadApk(
            any(),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) => pendente.future);
      when(() => service.install(any())).thenAnswer((_) async {});

      final primeira = vm.startUpdate();
      await vm.startUpdate();

      verify(() => service.downloadApk(
            any(),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
          )).called(1);

      pendente.complete(File('simtc-1.1.0-2.apk'));
      await primeira;
    });

    test('cancelDownload → volta a available, sem erro', () async {
      await carregarVersaoNova();
      when(() => service.downloadApk(
            any(),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((inv) async {
        final token = inv.namedArguments[#cancelToken] as CancelToken;
        await token.whenCancel;
        throw const AppUpdateException(AppUpdateFailure.download, 'cancelado');
      });

      final atualizando = vm.startUpdate();
      vm.cancelDownload();
      await atualizando;

      expect(vm.status, UpdateStatus.available);
      expect(vm.errorMessage, isNull);
      expect(vm.hasUpdate, isTrue);
    });

    test('fila ocupada → não começa (no-op)', () async {
      await carregarVersaoNova();
      sync.setQueue([queuedAssessment('p1')]);

      await vm.startUpdate();

      expect(vm.status, UpdateStatus.available);
      verifyNever(() => service.downloadApk(
            any(),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
          ));
    });
  });

  group('dismiss', () {
    test('em versão obrigatória é ignorado', () async {
      await carregarVersaoNova(obrigatoria: true);

      vm.dismiss();

      expect(vm.status, UpdateStatus.available);
      expect(vm.mandatory, isTrue);
    });
  });
}
