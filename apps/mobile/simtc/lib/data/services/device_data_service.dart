import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'local/app_database.dart';
import 'local/token_storage.dart';

/// O cache em disco dos logos das empresas: o `DefaultCacheManager`, usado
/// pelo `CompanyLogo` e pelo `cached_network_image`. Os arquivos ficam na
/// pasta temporária do app, numa subpasta com a chave do gerenciador.
class LogoCache {
  const LogoCache();

  Future<int> sizeInBytes() async {
    final temp = await getTemporaryDirectory();
    final folder = Directory(
      '${temp.path}${Platform.pathSeparator}${DefaultCacheManager.key}',
    );
    if (!await folder.exists()) return 0;
    var total = 0;
    await for (final entry in folder.list(recursive: true, followLinks: false)) {
      if (entry is File) total += await entry.length();
    }
    return total;
  }

  Future<void> clear() => DefaultCacheManager().emptyCache();
}

/// Os dados guardados no aparelho como um todo (Fase 8A): o "Limpar cache
/// local" do Perfil e a limpeza ao trocar de servidor.
class DeviceDataService {
  DeviceDataService({
    required AppDatabase database,
    required TokenStorage storage,
    LogoCache logos = const LogoCache(),
  })  : _db = database,
        _storage = storage,
        _logos = logos;

  final AppDatabase _db;
  final TokenStorage _storage;
  final LogoCache _logos;

  /// Na abertura, antes de retomar a sessão: se o app fala agora com outro
  /// servidor ([apiBaseUrl]) que não o da última abertura, apaga tudo o que
  /// está no aparelho — sessões, catálogo, fila, rascunhos, logos e o login —
  /// e guarda o endereço novo (decisão de 24/10/2026). Sem isso, a fila feita
  /// contra um servidor iria para o outro, com ids que lá não existem, e
  /// ficaria como "Erro" para sempre. Devolve se apagou.
  ///
  /// Nenhum endereço guardado (a primeira abertura depois da Fase 8A, ou do
  /// app recém-instalado) conta como troca. Se o armazenamento seguro não
  /// consegue nem ler o endereço (keystore invalidada), nada é apagado: sem
  /// saber o servidor anterior, apagar a fila a cada abertura seria pior do
  /// que o risco que a limpeza evita.
  Future<bool> resetIfServerChanged(String apiBaseUrl) async {
    final String? saved;
    try {
      saved = await _storage.readApiBaseUrl();
    } catch (_) {
      return false;
    }
    if (saved == apiBaseUrl) return false;

    await _db.clearAll();
    try {
      await _storage.clear();
    } catch (_) {
      // Tokens de outro servidor que sobrarem são recusados por este, e a
      // primeira chamada leva ao login.
    }
    await _clearLogos();
    try {
      await _storage.saveApiBaseUrl(apiBaseUrl);
    } catch (_) {
      // Sem gravar, a próxima abertura apaga de novo — o banco já está vazio.
    }
    return true;
  }

  /// O espaço que o "Limpar cache local" libera, em bytes: o banco local e os
  /// logos baixados. A fila e os rascunhos também moram no banco, mas ocupam
  /// poucos kB.
  Future<int> downloadedBytes() async {
    final database = await _db.usedBytes();
    var logos = 0;
    try {
      logos = await _logos.sizeInBytes();
    } catch (_) {
      // Pasta ilegível: conta só o banco.
    }
    return database + logos;
  }

  /// "Limpar cache local": apaga sessões, participantes, consultores,
  /// catálogo e logos baixados — nunca a fila nem os rascunhos. A Home baixa
  /// tudo de novo na próxima vez que abrir.
  Future<void> clearDownloaded() async {
    await _db.clearDownloadedData();
    await _clearLogos();
  }

  Future<void> _clearLogos() async {
    try {
      await _logos.clear();
    } catch (_) {
      // Logos são só imagem: os que sobrarem não fazem mal a ninguém.
    }
  }
}
