import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/app_log.dart';
import '../../utils/result.dart';
import '../models/app_release.dart';

/// Por que a atualização falhou, para a ViewModel escolher a mensagem.
enum AppUpdateFailure { download, checksum, install }

class AppUpdateException implements Exception {
  const AppUpdateException(this.failure, [this.detail]);

  final AppUpdateFailure failure;
  final String? detail;

  @override
  String toString() =>
      'AppUpdateException($failure${detail == null ? '' : ': $detail'})';
}

/// Abre o instalador do Android para um APK já baixado.
abstract interface class ApkInstaller {
  /// `true` se o instalador abriu; `false` se o Android recusou.
  Future<bool> install(String filePath);
}

/// O instalador de verdade: o Android abre a tela "Instalar" para o arquivo.
class OpenFileApkInstaller implements ApkInstaller {
  const OpenFileApkInstaller();

  @override
  Future<bool> install(String filePath) async {
    final result = await OpenFilex.open(
      filePath,
      type: 'application/vnd.android.package-archive',
    );
    return result.type == ResultType.done;
  }
}

typedef VersionCodeLoader = Future<int> Function();
typedef DirectoryLoader = Future<Directory> Function();

/// Atualização do app dentro do próprio app: descobre a versão mais recente no
/// `latest.json`, baixa o APK, confere o SHA-256 e abre o instalador.
///
/// O servidor é o bucket público `app-releases` do Supabase, e não o backend:
/// por isso usa um `Dio` próprio, sem o token nem o prefixo da API.
class AppUpdateService {
  AppUpdateService({
    required this.manifestUrl,
    Dio? dio,
    VersionCodeLoader? loadVersionCode,
    ApkInstaller? installer,
    DirectoryLoader? loadDownloadDirectory,
    DateTime Function()? clock,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
              ),
            ),
        _loadVersionCode = loadVersionCode ?? _platformVersionCode,
        _installer = installer ?? const OpenFileApkInstaller(),
        _loadDownloadDirectory = loadDownloadDirectory ?? getTemporaryDirectory,
        _clock = clock ?? DateTime.now;

  final String manifestUrl;
  final Dio _dio;
  final VersionCodeLoader _loadVersionCode;
  final ApkInstaller _installer;
  final DirectoryLoader _loadDownloadDirectory;
  final DateTime Function() _clock;

  /// No Android o `buildNumber` é o `versionCode` (o número depois do `+`).
  static Future<int> _platformVersionCode() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  Future<int> installedVersionCode() => _loadVersionCode();

  /// Lê o `latest.json`. Qualquer falha (sem rede, resposta torta) vira
  /// `Failure`: quem chama decide se avisa ou se ignora em silêncio.
  Future<Result<AppRelease>> fetchLatest() async {
    try {
      // O `ts` fura o cache do CDN: sem ele, um `latest.json` velho poderia
      // ser servido por horas depois de uma publicação.
      final base = Uri.parse(manifestUrl);
      final uri = base.replace(
        queryParameters: {
          ...base.queryParameters,
          'ts': '${_clock().millisecondsSinceEpoch}',
        },
      );
      // Texto puro, e o JSON é lido aqui: não depende do Content-Type com que
      // o Storage serve o arquivo.
      final response = await _dio.getUri<String>(
        uri,
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data;
      if (body == null) throw const FormatException('resposta vazia');

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('manifesto não é um objeto JSON');
      }
      return Success(AppRelease.fromJson(decoded));
    } on Exception catch (e) {
      appLog('Atualização: não consegui ler o latest.json ($e)');
      return Failure(e);
    }
  }

  /// Baixa o APK e confere o SHA-256. Se o arquivo já está no aparelho e
  /// íntegro (o usuário cancelou o instalador), reaproveita sem baixar de novo.
  ///
  /// Lança [AppUpdateException]; um arquivo que não bate com o hash é apagado.
  Future<File> downloadApk(
    AppRelease release, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final directory = await _loadDownloadDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}${release.fileName}');

    if (await file.exists()) {
      if (await _matchesHash(file, release.sha256)) {
        onProgress?.call(1);
        return file;
      }
      await _deleteQuietly(file);
    }

    try {
      await _dio.download(
        release.apkUrl,
        file.path,
        cancelToken: cancelToken,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
        onReceiveProgress: (received, total) {
          // Sem Content-Length, usa o tamanho que o manifesto declarou.
          final expected = total > 0 ? total : (release.sizeBytes ?? 0);
          if (expected > 0) {
            onProgress?.call((received / expected).clamp(0.0, 1.0).toDouble());
          }
        },
      );
    } on DioException catch (e) {
      await _deleteQuietly(file);
      throw AppUpdateException(AppUpdateFailure.download, e.type.name);
    } on FileSystemException catch (e) {
      await _deleteQuietly(file);
      throw AppUpdateException(AppUpdateFailure.download, e.message);
    }

    if (!await _matchesHash(file, release.sha256)) {
      await _deleteQuietly(file);
      throw const AppUpdateException(AppUpdateFailure.checksum);
    }
    return file;
  }

  /// Abre o instalador do Android. O usuário ainda toca em "Instalar".
  Future<void> install(File apk) async {
    final bool opened;
    try {
      opened = await _installer.install(apk.path);
    } on Exception catch (e) {
      throw AppUpdateException(AppUpdateFailure.install, e.toString());
    }
    if (!opened) throw const AppUpdateException(AppUpdateFailure.install);
  }

  /// Apaga da pasta de download os `simtc-*.apk` que não são mais úteis: todos,
  /// exceto o da versão em oferta ([keep], se houver). Falhas são silenciosas.
  Future<void> deleteStaleApks({AppRelease? keep}) async {
    try {
      final directory = await _loadDownloadDirectory();
      if (!await directory.exists()) return;
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('simtc-') || !name.endsWith('.apk')) continue;
        if (keep != null && name == keep.fileName) continue;
        await _deleteQuietly(entity);
      }
    } on Exception catch (e) {
      appLog('Atualização: não consegui limpar APKs antigos ($e)');
    }
  }

  Future<bool> _matchesHash(File file, String expected) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == expected.toLowerCase();
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Sobrou um arquivo parcial; o próximo download o substitui.
    }
  }
}
