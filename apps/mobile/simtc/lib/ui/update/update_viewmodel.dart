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
    Listenable? connectivityChanges,
    Future<bool> Function()? isOnWifi,
    this.enabled = true,
  })  : _service = service,
        _isOnline = isOnline,
        _isQueueIdle = isQueueIdle,
        _queueChanges = queueChanges,
        _connectivityChanges = connectivityChanges,
        _isOnWifi = isOnWifi ?? _defaultIsOnWifi;

  final AppUpdateService _service;
  final bool Function() _isOnline;

  /// Fila ociosa: nada sendo enviado e nenhuma avaliação aguardando envio
  /// (`pendingSync`). Itens recusados pelo servidor (`error`) não contam: não
  /// seguem sozinhos e não podem travar a atualização, nem a obrigatória. Só
  /// com a fila ociosa a atualização (automática ou manual) pode começar.
  final bool Function() _isQueueIdle;

  /// Avisa quando a fila muda; usado para rodar a checagem adiada.
  final Listenable _queueChanges;

  /// Avisa quando a rede muda; a diferida também é reavaliada então. Opcional:
  /// sem ele, a diferida ainda é resgatada pela fila e pela reabertura da Home.
  final Listenable? _connectivityChanges;

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

  /// A rede de AGORA não é Wi-Fi nem cabo: antes de baixar, o aviso pergunta
  /// se pode gastar dados móveis. Consultada no toque em "Atualizar", e não na
  /// checagem, porque a rede muda entre uma coisa e outra.
  Future<bool> needsWifiConfirmation() async => !await _safeIsOnWifi();

  /// A checagem achou versão nova, mas a Home não está no topo (o usuário está
  /// num checklist, por exemplo): em vez de abrir o aviso por cima, deixa-o
  /// pendente. A Home o abre quando voltar ao topo (ver [promptPending]).
  void deferPrompt() {
    if (_promptPending || _release == null) return;
    _promptPending = true;
    notifyListeners();
  }

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
    if (!enabled || _checkedThisSession || _busy) return false;
    if (_deferredOpenCheck) {
      // Reabrir a Home reavalia a diferida: com a fila ociosa e rede, roda agora
      // e o aviso sai na hora (promptPending não é ligado nesse caso).
      if (!_deferredReady()) return false;
      _stopDeferredOpenCheck();
      _checkedThisSession = true;
      await _check(silent: true);
      return _status == UpdateStatus.available;
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

  /// Pode rodar a checagem diferida agora? Nunca no meio de uma operação, nem
  /// com download ou instalador na tela, nem com versão já conhecida.
  bool _deferredReady() =>
      !_disposed &&
      !_busy &&
      _status != UpdateStatus.downloading &&
      _status != UpdateStatus.installing &&
      _release == null &&
      _isOnline() &&
      _isQueueIdle();

  void _deferOpenCheck() {
    if (_deferredOpenCheck) return;
    _deferredOpenCheck = true;
    _queueChanges.addListener(_onStateChanged);
    _connectivityChanges?.addListener(_onStateChanged);
  }

  /// Fila ou rede mudou: tenta a diferida. Depois de uma falha manual não
  /// roda, para não apagar a mensagem de erro que o usuário está vendo; a
  /// reabertura da Home ([checkOnOpen]) ainda resgata a checagem.
  void _onStateChanged() {
    if (_status == UpdateStatus.failed) return;
    _tryRunDeferredOpenCheck();
  }

  void _tryRunDeferredOpenCheck() {
    if (!_deferredOpenCheck || !_deferredReady()) return;
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
    if (!_deferredOpenCheck) return;
    _deferredOpenCheck = false;
    _queueChanges.removeListener(_onStateChanged);
    _connectivityChanges?.removeListener(_onStateChanged);
  }

  /// Uma checagem manual que deu certo já mostrou o resultado (com ou sem
  /// versão): a diferida deixa de existir, e a abertura não checa de novo.
  void _cancelDeferredOpenCheck() {
    _checkedThisSession = true;
    _stopDeferredOpenCheck();
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
          _cancelDeferredOpenCheck();
          await _service.deleteStaleApks(
            keep: release.isNewerThan(installed) ? release : null,
          );
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
  }

  /// "Atualizar": baixa, confere o hash e abre o instalador do Android.
  Future<void> startUpdate() async {
    final release = _release;
    if (release == null || _busy) return;
    if (!_isQueueIdle()) {
      // Sem isto o botão do aviso pareceria morto. A versão em oferta fica.
      _status = UpdateStatus.failed;
      _errorMessage = _mensagemFilaOcupada;
      notifyListeners();
      return;
    }

    _cancelDeferredOpenCheck();
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
      if (_cancelled) {
        // "Cancelar" tocado durante o cálculo do SHA-256 ou no reaproveitamento
        // do arquivo: o download já tinha terminado, mas o pedido vale.
        _status = UpdateStatus.available;
        return;
      }
      _status = UpdateStatus.installing;
      notifyListeners();
      await _service.install(file);
      // O instalador do Android está na tela. Se o usuário confirmar, o app é
      // substituído (o instalador oferece "Abrir"); se cancelar, continua aqui.
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
    _stopDeferredOpenCheck();
    _cancelToken?.cancel();
    super.dispose();
  }
}
