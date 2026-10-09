import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/models/cpf_lookup.dart';
import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../utils/cpf.dart';
import '../../utils/result.dart';

/// Em que pé está o CPF digitado em "Adicionar participante".
enum CpfCheck {
  /// Menos de 11 dígitos.
  incomplete,

  /// 11 dígitos, mas os verificadores não conferem.
  invalid,

  /// Válido; a consulta ao servidor está no ar.
  checking,

  /// Válido e fora desta sessão — com ou sem cadastro de outro treinamento.
  available,

  /// Já inscrito nesta sessão.
  enrolled,

  /// Válido, mas a consulta falhou: a tela segue como formulário simples, e
  /// o backend resolve o CPF repetido.
  unverified,
}

/// Estado da tela 1.11 "Adicionar participante" (Fase 6A), só para ADMIN.
///
/// O CPF é o primeiro campo (decisão de 06/10/2026): completo e válido, é
/// consultado no servidor, que diz se já está nesta sessão e, se a pessoa
/// tem cadastro de outro treinamento, devolve nome e e-mail para preencher.
/// Os campos continuam editáveis — o que estiver na tela ao adicionar é o que
/// o backend grava no cadastro, como já fazia.
///
/// O CPF inteiro só existe aqui, em memória, enquanto a tela está aberta.
class AddParticipantViewModel extends ChangeNotifier {
  AddParticipantViewModel({
    required this.sessionId,
    required SessionRepository sessionRepository,
    required ParticipantRepository participantRepository,
    required AuthUser? currentUser,
  })  : _sessionRepository = sessionRepository,
        _participantRepository = participantRepository,
        _currentUser = currentUser;

  final String sessionId;
  final SessionRepository _sessionRepository;
  final ParticipantRepository _participantRepository;
  final AuthUser? _currentUser;

  static const String _addFailed =
      'Não foi possível adicionar o participante. Tente de novo.';

  /// Só para barrar erro de digitação no endereço que recebe o certificado:
  /// algo, arroba, algo, ponto, algo — sem espaços. O backend não confere.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  StreamSubscription<TrainingSession?>? _sessionSubscription;

  bool _disposed = false;
  bool _loaded = false;
  TrainingSession? _session;

  String _cpf = '';
  String _name = '';
  String _email = '';
  ParticipationType _type = ParticipationType.teoricaEPratica;
  CpfCheck _cpfCheck = CpfCheck.incomplete;

  /// Nome de quem já está na sessão com este CPF, quando a consulta o trouxe.
  String? _enrolledName;

  /// O que a consulta pôs nos campos. Enquanto o campo ainda tiver este
  /// valor, trocar o CPF o limpa — a pessoa passou a ser outra.
  String? _autoName;
  String? _autoEmail;
  bool _filledFromRegistry = false;

  bool _submitting = false;
  String? _error;
  int _addedCount = 0;

  /// Antes da primeira leitura do cache.
  bool get isLoading => !_loaded;

  /// A sessão no cache agora — o contexto do topo da tela.
  TrainingSession? get session => _session;

  /// Só os dígitos.
  String get cpf => _cpf;
  String get name => _name;
  String get email => _email;
  ParticipationType get participationType => _type;
  CpfCheck get cpfCheck => _cpfCheck;

  /// Nome e/ou e-mail vieram do cadastro de outro treinamento.
  bool get filledFromRegistry => _filledFromRegistry;

  /// O aviso de que os campos foram preenchidos pelo cadastro, dizendo quais;
  /// nulo quando nada veio de lá.
  String? get registryNotice {
    if (!_filledFromRegistry) return null;
    final filled = _autoName != null && _autoEmail != null
        ? 'nome e e-mail preenchidos'
        : _autoName != null
            ? 'nome preenchido'
            : 'e-mail preenchido';
    return 'Já cadastrado em outro treinamento: $filled. Altere se precisar.';
  }

  bool get isSubmitting => _submitting;

  /// Falha do último "adicionar", mostrada na própria tela; some quando o
  /// admin mexe num campo.
  String? get errorMessage => _error;

  /// Quantos participantes entraram desde que a tela abriu — com "Salvar e
  /// adicionar outro", pode ser mais de um. A tela de baixo se atualiza se
  /// for maior que zero.
  int get addedCount => _addedCount;

  /// Há algo digitado: fechar a tela pede confirmação.
  bool get hasInput =>
      _cpf.isNotEmpty || _name.trim().isNotEmpty || _email.trim().isNotEmpty;

  /// Por que o formulário está travado; nulo quando dá para adicionar.
  String? get lockedReason {
    if (_currentUser?.isAdmin != true) {
      return 'Só administradores podem adicionar participantes.';
    }
    final session = _session;
    if (session == null) {
      return 'Esta sessão não está mais disponível neste aparelho.';
    }
    if (session.status.acceptsChanges) return null;
    return session.status == SessionStatus.cancelado
        ? 'Sessão cancelada: não dá mais para adicionar participantes.'
        : 'Sessão concluída: não dá mais para adicionar participantes.';
  }

  bool get canAdd => _loaded && lockedReason == null;

  /// Erro sob o CPF: dígitos que não conferem, ou já inscrito nesta sessão.
  String? get cpfError => switch (_cpfCheck) {
        CpfCheck.invalid => 'CPF inválido.',
        CpfCheck.enrolled => _enrolledName == null
            ? 'Este CPF já está nesta sessão.'
            : '$_enrolledName já está nesta sessão.',
        _ => null,
      };

  /// Texto de apoio sob o CPF, quando não há erro.
  String? get cpfHelper => switch (_cpfCheck) {
        CpfCheck.checking => 'Consultando o CPF…',
        CpfCheck.available => 'CPF válido e sem cadastro nesta sessão.',
        CpfCheck.unverified =>
          'Não foi possível consultar o CPF. Preencha os dados e adicione '
              'assim mesmo.',
        _ => null,
      };

  /// Vazio vale: o e-mail é opcional.
  bool get isEmailValid {
    final email = _email.trim();
    return email.isEmpty || _emailPattern.hasMatch(email);
  }

  bool get canSubmit =>
      canAdd &&
      !_submitting &&
      (_cpfCheck == CpfCheck.available || _cpfCheck == CpfCheck.unverified) &&
      _name.trim().isNotEmpty &&
      isEmailValid;

  /// Assina o cache da sessão. Chamado uma vez pela tela.
  void init() {
    _sessionSubscription ??=
        _sessionRepository.watchSession(sessionId).listen((session) {
      _session = session;
      _loaded = true;
      notifyListeners();
    });
  }

  /// Aceita o CPF com ou sem máscara. Completo e válido, dispara a consulta.
  void setCpf(String value) {
    final digits = cpfDigits(value);
    final cpf = digits.length > 11 ? digits.substring(0, 11) : digits;
    if (cpf == _cpf) return;

    _cpf = cpf;
    _error = null;
    _enrolledName = null;
    _clearRegistryFill();

    if (cpf.length < 11) {
      _cpfCheck = CpfCheck.incomplete;
    } else if (!isValidCpf(cpf)) {
      _cpfCheck = CpfCheck.invalid;
    } else {
      _cpfCheck = CpfCheck.checking;
      unawaited(_lookup(cpf));
    }
    notifyListeners();
  }

  void setName(String value) {
    _name = value;
    _edited();
  }

  void setEmail(String value) {
    _email = value;
    _edited();
  }

  void setParticipationType(ParticipationType value) {
    _type = value;
    _edited();
  }

  void _edited() {
    _error = null;
    notifyListeners();
  }

  Future<void> _lookup(String cpf) async {
    Result<CpfLookup> result;
    try {
      result = await _participantRepository.lookupCpf(sessionId, cpf);
    } catch (error) {
      result = Failure(Exception('$error'));
    }
    // Resposta atrasada: a tela fechou, ou o CPF já é outro.
    if (_disposed || cpf != _cpf) return;

    switch (result) {
      case Success(:final data) when data.enrolled:
        _cpfCheck = CpfCheck.enrolled;
        _enrolledName = data.name;
        // A pessoa já está na sessão lá no servidor — entrou pelo QR code, pelo
        // painel ou por um envio nosso cuja resposta se perdeu. A lista do
        // detalhe lê o cache: sem baixar a sessão de novo, ela não aparece
        // nela até o admin puxar para atualizar.
        unawaited(_participantRepository.syncSession(sessionId));
      case Success(:final data):
        _cpfCheck = CpfCheck.available;
        if (data.registered) _fillFromRegistry(data);
      case Failure():
        _cpfCheck = CpfCheck.unverified;
    }
    notifyListeners();
  }

  /// O cadastro toma o lugar do que estiver nos campos — é o dado que a
  /// pessoa já tem no sistema. Sem e-mail no cadastro, o campo fica como está.
  void _fillFromRegistry(CpfLookup lookup) {
    final name = lookup.name;
    final email = lookup.email;
    if (name == null && email == null) return;

    if (name != null) {
      _name = name;
      _autoName = name;
    }
    if (email != null) {
      _email = email;
      _autoEmail = email;
    }
    _filledFromRegistry = true;
  }

  /// O CPF mudou: o que veio do cadastro anterior sai, a não ser que o admin
  /// tenha mexido no campo. Sem isso, a pessoa nova seria salva com o nome
  /// da anterior.
  void _clearRegistryFill() {
    if (_autoName != null && _name == _autoName) _name = '';
    if (_autoEmail != null && _email == _autoEmail) _email = '';
    _autoName = null;
    _autoEmail = null;
    _filledFromRegistry = false;
  }

  /// "Adicionar participante" e, com [addAnother], "Salvar e adicionar
  /// outro" — que limpa o formulário para o próximo. Devolve quem entrou, ou
  /// nulo se não entrou: o motivo fica em [errorMessage], ou sob o CPF quando
  /// ele já está na sessão.
  Future<SessionParticipant?> submit({bool addAnother = false}) async {
    if (!canSubmit) return null;

    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      final email = _email.trim();
      final result = await _participantRepository.add(
        sessionId,
        cpf: _cpf,
        name: _name.trim(),
        email: email.isEmpty ? null : email,
        participationType: _type,
      );
      switch (result) {
        case Success(:final data):
          _addedCount++;
          if (addAnother) _reset();
          return data;
        case Failure(:final exception, :final message):
          _refused(exception, message);
          return null;
      }
    } catch (_) {
      _error = _addFailed;
      return null;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  void _refused(Exception exception, String? message) {
    final status = exception is ApiException ? exception.statusCode : null;
    if (status == 409) {
      // Outra pessoa inscreveu este CPF entre a consulta e o toque — ou o nosso
      // envio foi aceito e a resposta se perdeu. A lista do detalhe lê o cache:
      // sem baixar a sessão de novo, a pessoa não aparece nela até o admin
      // puxar para atualizar.
      _cpfCheck = CpfCheck.enrolled;
      _enrolledName = null;
      unawaited(_participantRepository.syncSession(sessionId));
      return;
    }

    _error = message ?? _addFailed;
    // 400: inscrições encerradas (a sessão foi concluída ou cancelada); 404:
    // a sessão foi apagada. Baixar de novo põe o cache — e esta tela — em dia.
    if (status == 400 || status == 404) {
      unawaited(_participantRepository.syncSession(sessionId));
    }
  }

  void _reset() {
    _cpf = '';
    _name = '';
    _email = '';
    _type = ParticipationType.teoricaEPratica;
    _cpfCheck = CpfCheck.incomplete;
    _enrolledName = null;
    _autoName = null;
    _autoEmail = null;
    _filledFromRegistry = false;
  }

  // A consulta e o "adicionar" podem responder depois de a tela fechar.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
