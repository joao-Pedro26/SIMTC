import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
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

/// Padrão de [UpdateViewModel.isOnWifi]: Wi-Fi ou cabo. Erro conta como fora do
/// Wi-Fi, que é o lado seguro (o aviso de dados aparece).
Future<bool> _defaultIsOnWifi() async {
  try {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
  } on Exception {
    return false;
  }
}

/// Estado da atualização do app dentro do próprio app.
///
/// Criada uma única vez no `AppDependencies`: a checagem da abertura e a do
/// Perfil enxergam o mesmo estado.
class UpdateViewModel extends ChangeNotifier {
  UpdateViewModel({
    required AppUpdateService service,
    required bool Function() isOnline,
    required bool Function() isQueueIdle,
    required Listenable queueChanges,
    Future<bool> Function()? isOnWifi,
    this.enabled = true,
  })  : _service = service,
        _isOnline = isOnline,
        _isQueueIdle = isQueueIdle,
        _queueChanges = queueChanges,
        _isOnWifi = isOnWifi ?? _defaultIsOnWifi;

  final AppUpdateService _service;
  final bool Function() _isOnline;

  /// Fila ociosa: nada sendo enviado e nada na fila. Só nesse estado a
  /// atualização automática e a instalação podem começar.
  final bool Function() _isQueueIdle;

  /// Avisa quando a fila muda; usado para rodar a checagem adiada.
  final Listenable _queueChanges;

  final Future<bool> Function() _isOnWifi;

  /// Desliga a checagem automática (builds de debug e testes). A checagem
  /// manual do Perfil funciona sempre.
  final bool enabled;

  UpdateStatus _status = UpdateStatus.idle;
  AppRelease? _release;
  bool _mandatory = false;
  double _progress = 0;
  String? _errorMessage;
  bool _promptPending = false;
  bool _confirmNotOnWifi = false;

  bool _checkedThisSession = false;
  bool _busy = false;
  bool _cancelled = false;
  bool _disposed = false;
  bool _deferredOpenCheck = false;
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

  /// Aviso diferido da abertura: a checagem rodou depois que a fila ficou
  /// ociosa e achou versão nova. A Home deve abri-lo e chamar [markPromptShown].
  bool get promptPending => _promptPending;

  /// A versão foi achada fora do Wi-Fi: o aviso deve falar de dados móveis.
  bool get confirmNotOnWifi => _confirmNotOnWifi;

  /// O aviso diferido foi mostrado; desliga [promptPending].
  void markPromptShown() {
    if (!_promptPending) return;
    _promptPending = false;
    notifyListeners();
  }

  /// Checagem da abertura do app: uma vez por abertura, só com rede, e sem
  /// nunca incomodar com erro.
  ///
  /// Com a fila ocupada, não consome a checagem: guarda como pendente e roda
  /// quando a fila ficar ociosa (ver [promptPending]).
  ///
  /// Devolve `true` só se esta chamada achou uma versão nova — é quando a tela
  /// mostra o aviso. Telas que reabrem a Home não repetem o aviso.
  Future<bool> checkOnOpen() async {
    if (!enabled || _checkedThisSession || _busy || _deferredOpenCheck) {
      return false;
    }
    if (!_isOnline()) return false;
    if (!_isQueueIdle()) {
      _deferOpenCheck();
      return false;
    }
    _checkedThisSession = true;
    await _check(silent: true);
    return _status == UpdateStatus.available;
  }

  void _deferOpenCheck() {
    _deferredOpenCheck = true;
    _queueChanges.addListener(_onQueueChanged);
  }

  void _onQueueChanged() {
    if (!_deferredOpenCheck || _busy || !_isQueueIdle()) return;
    // Sem rede a checagem continua pendente até a próxima mudança da fila.
    if (!_isOnline()) return;

    _stopDeferredOpenCheck();
    _checkedThisSession = true;
    unawaited(_runDeferredOpenCheck());
  }

  Future<void> _runDeferredOpenCheck() async {
    await _check(silent: true);
    if (_disposed) return;
    if (_status == UpdateStatus.available) {
      _promptPending = true;
      notifyListeners();
    }
  }

  void _stopDeferredOpenCheck() {
    _deferredOpenCheck = false;
    _queueChanges.removeListener(_onQueueChanged);
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
    if (!_isQueueIdle()) {
      _status = UpdateStatus.failed;
      _errorMessage = _mensagemFilaOcupada;
      notifyListeners();
      return;
    }
    await _check(silent: false);
  }

  static const String _mensagemFilaOcupada =
      'Aguarde o envio das avaliações terminar e tente de novo.';

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
            _confirmNotOnWifi = !await _safeIsOnWifi();
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

  Future<bool> _safeIsOnWifi() async {
    try {
      return await _isOnWifi();
    } on Exception {
      return false;
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
    _confirmNotOnWifi = false;
  }

  /// "Atualizar": baixa, confere o hash e abre o instalador do Android.
  Future<void> startUpdate() async {
    final release = _release;
    if (release == null || _busy) return;
    if (!_isQueueIdle()) return;

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
    if (_deferredOpenCheck) _stopDeferredOpenCheck();
    _cancelToken?.cancel();
    super.dispose();
  }
}
