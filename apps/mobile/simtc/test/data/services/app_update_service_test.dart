import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/app_release.dart';
import 'package:simtc/data/services/app_update_service.dart';
import 'package:simtc/utils/app_log.dart';
import 'package:simtc/utils/result.dart';

const String _manifestUrl =
    'https://x.supabase.co/storage/v1/object/public/app-releases/latest.json?v=1';

/// Instante fixo usado como `clock` do serviço.
final DateTime _agora = DateTime.fromMillisecondsSinceEpoch(1700000000000);

/// Adaptador de HTTP falso: não há rede. Cada requisição é entregue ao
/// `responder` do teste, que devolve a resposta (ou lança o erro) desejado.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  Future<ResponseBody> Function(RequestOptions options) responder;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

class _MockInstaller extends Mock implements ApkInstaller {}

/// Corpo de texto puro, como o `latest.json` chega do bucket.
ResponseBody _texto(String corpo) => ResponseBody.fromString(corpo, 200);

/// APK falso com `Content-Length`, para o progresso do download ser calculado.
ResponseBody _apk(List<int> bytes) => ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );

Map<String, dynamic> _manifesto({required String sha256}) => {
      'versionName': '1.1.0',
      'versionCode': 2,
      'minSupportedVersionCode': 1,
      'apkUrl':
          'https://x.supabase.co/storage/v1/object/public/app-releases/simtc-1.1.0-2.apk',
      'sha256': sha256,
      'sizeBytes': 9,
      'releaseNotes': ['Corrige X'],
    };

void main() {
  late Directory temp;
  late _FakeAdapter adapter;
  late Dio dio;
  late _MockInstaller installer;
  late AppUpdateService service;
  late AppLogSink logOriginal;

  final bytesApk = utf8.encode('apk falso');
  final hashApk = sha256.convert(bytesApk).toString();

  AppRelease releaseComHash(String hash) =>
      AppRelease.fromJson(_manifesto(sha256: hash));

  File arquivoDoRelease(AppRelease release) =>
      File('${temp.path}${Platform.pathSeparator}${release.fileName}');

  setUp(() async {
    logOriginal = appLogSink;
    appLogSink = (_) {};
    temp = await Directory.systemTemp.createTemp('app_update_service_test');
    adapter = _FakeAdapter((_) async => _texto('{}'));
    dio = Dio()..httpClientAdapter = adapter;
    installer = _MockInstaller();
    service = AppUpdateService(
      manifestUrl: _manifestUrl,
      dio: dio,
      loadVersionCode: () async => 1,
      installer: installer,
      loadDownloadDirectory: () async => temp,
      clock: () => _agora,
    );
  });

  tearDown(() async {
    appLogSink = logOriginal;
    dio.close(force: true);
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('fetchLatest', () {
    test('devolve o release lido do manifesto', () async {
      adapter.responder = (_) async => _texto(jsonEncode(_manifesto(
            sha256: hashApk,
          )));

      final result = await service.fetchLatest();

      expect(result, isA<Success<AppRelease>>());
      final release = (result as Success<AppRelease>).data;
      expect(release.versionName, '1.1.0');
      expect(release.versionCode, 2);
      expect(release.sha256, hashApk);
    });

    test('pede o manifesto com ts do clock e preserva a query original',
        () async {
      adapter.responder = (_) async => _texto(jsonEncode(_manifesto(
            sha256: hashApk,
          )));

      await service.fetchLatest();

      expect(adapter.requests, hasLength(1));
      final uri = adapter.requests.single.uri;
      expect(uri.path, '/storage/v1/object/public/app-releases/latest.json');
      expect(uri.queryParameters['v'], '1');
      expect(uri.queryParameters['ts'], '${_agora.millisecondsSinceEpoch}');
    });

    test('corpo que não é JSON vira Failure sem lançar', () async {
      adapter.responder = (_) async => _texto('isto não é json');

      final result = await service.fetchLatest();

      expect(result, isA<Failure<AppRelease>>());
      expect(result.exceptionOrNull, isA<FormatException>());
    });

    test('JSON que não é objeto (lista) vira Failure sem lançar', () async {
      adapter.responder = (_) async => _texto('[1, 2, 3]');

      final result = await service.fetchLatest();

      expect(result, isA<Failure<AppRelease>>());
      expect(result.exceptionOrNull, isA<FormatException>());
    });

    test('release inválido no manifesto vira Failure sem lançar', () async {
      adapter.responder = (_) async => _texto(jsonEncode({
            ..._manifesto(sha256: hashApk),
            'versionName': '',
          }));

      final result = await service.fetchLatest();

      expect(result, isA<Failure<AppRelease>>());
      expect(result.exceptionOrNull, isA<FormatException>());
    });

    test('timeout de conexão vira Failure sem lançar', () async {
      adapter.responder = (options) async => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          );

      final result = await service.fetchLatest();

      expect(result, isA<Failure<AppRelease>>());
      expect(result.exceptionOrNull, isA<DioException>());
    });

    test('erro de conexão vira Failure sem lançar', () async {
      adapter.responder = (options) async => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );

      final result = await service.fetchLatest();

      expect(result, isA<Failure<AppRelease>>());
      expect(result.exceptionOrNull, isA<DioException>());
    });
  });

  group('downloadApk', () {
    test(
        'com bytes de SHA-256 correto, grava o arquivo e termina o progresso em 1.0',
        () async {
      final release = releaseComHash(hashApk);
      adapter.responder = (_) async => _apk(bytesApk);
      final progresso = <double>[];

      final file = await service.downloadApk(
        release,
        onProgress: progresso.add,
      );

      expect(file.path, arquivoDoRelease(release).path);
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), bytesApk);
      expect(progresso, isNotEmpty);
      expect(progresso.last, 1.0);
    });

    test('com SHA-256 diferente, lança checksum e apaga o arquivo', () async {
      final release = releaseComHash('0' * 64);
      adapter.responder = (_) async => _apk(bytesApk);

      await expectLater(
        service.downloadApk(release),
        throwsA(isA<AppUpdateException>().having(
          (e) => e.failure,
          'failure',
          AppUpdateFailure.checksum,
        )),
      );
      expect(await arquivoDoRelease(release).exists(), isFalse);
    });

    test('erro de rede no download lança download e não deixa arquivo parcial',
        () async {
      final release = releaseComHash(hashApk);
      adapter.responder = (options) async => ResponseBody(
            Stream<Uint8List>.multi((controller) {
              controller.add(Uint8List.fromList([1, 2, 3]));
              controller.addError(DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ));
              controller.close();
            }),
            200,
          );

      await expectLater(
        service.downloadApk(release),
        throwsA(isA<AppUpdateException>().having(
          (e) => e.failure,
          'failure',
          AppUpdateFailure.download,
        )),
      );
      expect(await arquivoDoRelease(release).exists(), isFalse);
    });

    test('arquivo já presente e íntegro é reaproveitado sem baixar de novo',
        () async {
      final release = releaseComHash(hashApk);
      await arquivoDoRelease(release).writeAsBytes(bytesApk);
      adapter.responder = (_) async => _apk(bytesApk);
      final progresso = <double>[];

      final file = await service.downloadApk(
        release,
        onProgress: progresso.add,
      );

      expect(adapter.requests, isEmpty);
      expect(file.path, arquivoDoRelease(release).path);
      expect(await file.readAsBytes(), bytesApk);
      expect(progresso, [1.0]);
    });

    test('arquivo presente e corrompido é apagado e baixado de novo', () async {
      final release = releaseComHash(hashApk);
      await arquivoDoRelease(release).writeAsBytes(utf8.encode('lixo'));
      adapter.responder = (_) async => _apk(bytesApk);

      final file = await service.downloadApk(release);

      expect(adapter.requests, hasLength(1));
      expect(await file.readAsBytes(), bytesApk);
    });
  });

  group('install', () {
    test('quando o instalador abre, completa sem erro', () async {
      final apk = arquivoDoRelease(releaseComHash(hashApk));
      when(() => installer.install(apk.path)).thenAnswer((_) async => true);

      await expectLater(service.install(apk), completes);
      verify(() => installer.install(apk.path)).called(1);
    });

    test('quando o Android recusa abrir o instalador, lança install', () async {
      final apk = arquivoDoRelease(releaseComHash(hashApk));
      when(() => installer.install(apk.path)).thenAnswer((_) async => false);

      await expectLater(
        service.install(apk),
        throwsA(isA<AppUpdateException>().having(
          (e) => e.failure,
          'failure',
          AppUpdateFailure.install,
        )),
      );
    });

    test('quando o instalador lança, vira AppUpdateException install', () async {
      final apk = arquivoDoRelease(releaseComHash(hashApk));
      when(() => installer.install(apk.path))
          .thenThrow(Exception('plataforma indisponível'));

      await expectLater(
        service.install(apk),
        throwsA(isA<AppUpdateException>().having(
          (e) => e.failure,
          'failure',
          AppUpdateFailure.install,
        )),
      );
    });
  });
}
