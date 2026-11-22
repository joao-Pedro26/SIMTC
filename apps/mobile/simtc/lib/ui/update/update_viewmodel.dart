import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/app_release.dart';
import '../../data/services/app_update_service.dart';
import '../../utils/result.dart';

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,

  /// O instalador do Android foi aberto; se o usuário o cancelar, volta ao app
  /// e pode abrir de novo.
  installing,
  failed,
}

/// Estado da atualização do app dentro do próprio app.
///
/// Criada uma única vez no `AppDependencies`: a checagem da abertura e a do
/// Perfil enxergam o mesmo estado.
class UpdateViewModel extends ChangeNotifier {
  UpdateViewModel({
    required AppUpdateService service,
    required bool Function() isOnline,
    required bool Function() isSending,
    this.enabled = true,
  })  : _service = service,
        _isOnline = isOnline,
        _isSending = isSending;

  final AppUpdateService _service;
  final bool Function() _isOnline;

  /// A fila de avaliações está sendo enviada agora; não vale interromper.
  final bool Function() _isSending;

  /// Desliga a checagem automática (builds de debug e testes). A checagem
  /// manual do Perfil funciona sempre.
  final bool enabled;

  UpdateStatus _status = UpdateStatus.idle;
  AppRelease? _release;
  bool _mandatory = false;
  double _progress = 0;
  String? _errorMessage;

  bool _checkedThisSession = false;
  bool _busy = false;
  bool _cancelled = false;
  bool _disposed = false;
  CancelToken? _cancelToken;

  UpdateStatus get status => _status;

  /// A versão nova, quando há. Nula se o app está em dia ou a checagem falhou.
  AppRelease? get release => _release;
  bool get hasUpdate => _release != null;

  /// A instalada é antiga demais: o aviso não pode ser dispensado.
  bool get mandatory => _mandatory;

  /// Progresso do download, de 0 a 1.
  double get progress => _progress;

  String? get errorMessage => _errorMessage;

  /// Checagem da abertura do app: uma vez por abertura, só com rede e sem
  /// envio da fila em andamento, e sem nunca incomodar com erro.
  ///
  /// Devolve `true` só se esta chamada achou uma versão nova — é quando a tela
  /// mostra o aviso. Telas que reabrem a Home não repetem o aviso.
  Future<bool> checkOnOpen() async {
    if (!enabled || _checkedThisSession || _busy) return false;
    if (!_isOnline() || _isSending()) return false;
    _checkedThisSession = true;
    await _check(silent: true);
    return _status == UpdateStatus.available;
  }

  /// "Verificar atualização" do Perfil: mostra o resultado, inclusive o erro.
  Future<void> checkNow() async {
    if (_busy) return;
    if (!_isOnline()) {
      _status = UpdateStatus.failed;
      _errorMessage = 'Sem conexão. Conecte-se à internet para verificar.';
      notifyListeners();
      return;
    }
    await _check(silent: false);
  }

  Future<void> _check({required bool silent}) async {
    _busy = true;
    _status = UpdateStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final installed = await _service.installedVersionCode();
      final result = await _service.fetchLatest();
      switch (result) {
        case Success(data: final release):
          if (release.isNewerThan(installed)) {
            _release = release;
            _mandatory = release.isMandatoryFor(installed);
            _status = UpdateStatus.available;
          } else {
            _clearRelease();
            _status = UpdateStatus.upToDate;
          }
        case Failure():
          _failCheck(silent);
      }
    } on Exception {
      _failCheck(silent);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _failCheck(bool silent) {
    _clearRelease();
    if (silent) {
      _status = UpdateStatus.idle;
    } else {
      _status = UpdateStatus.failed;
      _errorMessage =
          'Não foi possível verificar atualizações. Tente de novo mais tarde.';
    }
  }

  void _clearRelease() {
    _release = null;
    _mandatory = false;
  }

  /// "Atualizar": baixa, confere o hash e abre o instalador do Android.
  Future<void> startUpdate() async {
    final release = _release;
    if (release == null || _busy) return;

    _busy = true;
    _cancelled = false;
    _progress = 0;
    _errorMessage = null;
    _status = UpdateStatus.downloading;
    _cancelToken = CancelToken();
    notifyListeners();

    try {
      final file = await _service.downloadApk(
        release,
        cancelToken: _cancelToken,
        onProgress: (value) {
          _progress = value;
          notifyListeners();
        },
      );
      _status = UpdateStatus.installing;
      notifyListeners();
      await _service.install(file);
      // O instalador do Android está na tela. Se o usuário confirmar, o app é
      // substituído e reabre sozinho; se cancelar, continua aqui.
    } on AppUpdateException catch (e) {
      if (_cancelled) {
        _status = UpdateStatus.available;
      } else {
        _status = UpdateStatus.failed;
        _errorMessage = _messageFor(e.failure);
      }
    } on Exception {
      _status = UpdateStatus.failed;
      _errorMessage = _messageFor(AppUpdateFailure.download);
    } finally {
      _busy = false;
      _cancelToken = null;
      notifyListeners();
    }
  }

  /// "Cancelar" durante o download: volta ao aviso, sem erro.
  void cancelDownload() {
    if (_status != UpdateStatus.downloading) return;
    _cancelled = true;
    _cancelToken?.cancel();
  }

  /// "Depois": fecha o aviso. Não vale para a atualização obrigatória nem no
  /// meio do download.
  void dismiss() {
    if (_mandatory || _status == UpdateStatus.downloading) return;
    _status = UpdateStatus.idle;
    notifyListeners();
  }

  String _messageFor(AppUpdateFailure failure) => switch (failure) {
        AppUpdateFailure.download =>
          'Não foi possível baixar a atualização. Confira a conexão e tente de novo.',
        AppUpdateFailure.checksum =>
          'O arquivo baixado está incompleto ou corrompido. Tente de novo.',
        AppUpdateFailure.install =>
          'Não foi possível abrir o instalador do Android. Tente de novo.',
      };

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelToken?.cancel();
    super.dispose();
  }
}
