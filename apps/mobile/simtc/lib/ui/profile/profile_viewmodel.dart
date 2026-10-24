import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/models/auth_user.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/device_data_service.dart';

/// Estado da tela 1.10 Perfil (Fase 8A): quem entrou, o espaço do cache, a
/// versão do app e as duas ações — "Limpar cache local" e "Sair da conta".
///
/// A fila e a última sincronização vêm do `AssessmentSyncService`, que a tela
/// já observa; esta ViewModel não as repete.
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required AuthRepository auth,
    required AssessmentRepository assessments,
    required DeviceDataService deviceData,
    Future<String> Function()? loadVersion,
  })  : _auth = auth,
        _assessments = assessments,
        _deviceData = deviceData,
        _loadVersion = loadVersion ?? platformVersion;

  final AuthRepository _auth;
  final AssessmentRepository _assessments;
  final DeviceDataService _deviceData;
  final Future<String> Function() _loadVersion;

  /// "1.0.0 (1)": o `version` e o `buildNumber` do `pubspec.yaml`.
  static Future<String> platformVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  }

  String? _version;
  int? _cacheBytes;
  bool _isClearing = false;
  bool _isLoggingOut = false;
  bool _disposed = false;

  /// Quem entrou. Nulo só no instante entre o "Sair" e a ida para o login.
  AuthUser? get user => _auth.currentUser;

  /// Nulo até ler (ou se a leitura falhar).
  String? get version => _version;

  /// O espaço que o "Limpar cache local" libera; nulo enquanto mede (ou se a
  /// medida falhar).
  int? get cacheBytes => _cacheBytes;

  bool get isClearing => _isClearing;
  bool get isLoggingOut => _isLoggingOut;

  /// Lê a versão e mede o cache. Chamado uma vez pela tela.
  void init() {
    unawaited(_readVersion());
    unawaited(measureCache());
  }

  Future<void> _readVersion() async {
    try {
      _version = await _loadVersion();
    } catch (_) {
      _version = null;
    }
    notifyListeners();
  }

  Future<void> measureCache() async {
    try {
      _cacheBytes = await _deviceData.downloadedBytes();
    } catch (_) {
      _cacheBytes = null;
    }
    notifyListeners();
  }

  /// "Limpar cache local", já confirmado. Devolve se limpou; em seguida mede
  /// de novo, para a linha mostrar o que sobrou.
  Future<bool> clearCache() async {
    if (_isClearing) return false;
    _isClearing = true;
    notifyListeners();

    var cleared = false;
    try {
      await _deviceData.clearDownloaded();
      cleared = true;
    } catch (_) {
      // A tela avisa; o que não foi apagado continua valendo.
    } finally {
      _isClearing = false;
      notifyListeners();
    }
    await measureCache();
    return cleared;
  }

  /// As avaliações iniciadas e ainda não confirmadas de quem entrou — o aviso
  /// da confirmação do "Sair". Na dúvida (sem usuário, erro do banco), zero.
  Future<int> countStartedDrafts() async {
    final userId = user?.id;
    if (userId == null) return 0;
    try {
      return await _assessments.countDrafts(userId);
    } catch (_) {
      return 0;
    }
  }

  /// "Sair da conta", já confirmado. Devolve se saiu; o roteador leva ao
  /// login sozinho quando o usuário some.
  Future<bool> logout() async {
    if (_isLoggingOut) return false;
    _isLoggingOut = true;
    notifyListeners();

    try {
      await _auth.logout();
      return true;
    } catch (_) {
      return false;
    } finally {
      _isLoggingOut = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
