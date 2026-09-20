import '../../data/models/training_session.dart';

/// Os três chips da tela 1.3.
enum SessionFilter {
  hoje('Hoje'),
  proximos7('Próximos 7 dias'),
  concluidas('Concluídas');

  const SessionFilter(this.label);

  final String label;
}

/// Um bloco da lista, com o cabeçalho que aparece acima dele.
class SessionGroup {
  SessionGroup({required this.title, required this.sessions});

  final String title;
  final List<TrainingSession> sessions;
}

const List<String> _meses = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

const List<String> _diasDaSemana = [
  'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom',
];

String _diaEMes(DateTime date) => '${date.day} ${_meses[date.month - 1]}';

String _diaDaSemana(DateTime date) => _diasDaSemana[date.weekday - 1];

DateTime _dia(DateTime value) => DateTime(value.year, value.month, value.day);

/// Uma sessão está "aberta" enquanto ainda pode receber avaliação.
bool _estaAberta(TrainingSession session) =>
    session.status == SessionStatus.planejado ||
    session.status == SessionStatus.emAndamento;

bool _ehHoje(TrainingSession session, DateTime hoje) =>
    _estaAberta(session) && session.date != null && _dia(session.date!) == hoje;

bool _ehProximos7(TrainingSession session, DateTime hoje) {
  if (!_estaAberta(session) || session.date == null) return false;
  final dia = _dia(session.date!);
  return dia.isAfter(hoje) && !dia.isAfter(hoje.add(const Duration(days: 7)));
}

bool _ehConcluida(TrainingSession session) =>
    session.status == SessionStatus.concluido;

/// Sem data, ou com data passada e ainda aberta: não cabe em nenhum chip, mas
/// não pode sumir da tela — o consultor precisa conseguir chegar nela.
bool _ehOutra(TrainingSession session, DateTime hoje) {
  if (!_estaAberta(session)) return false;
  if (session.date == null) return true;
  return _dia(session.date!).isBefore(hoje);
}

/// Quantas sessões o chip anuncia. Conta só o grupo principal do filtro — o
/// grupo "Outras" carrega o próprio número no cabeçalho, para o chip não
/// prometer um número diferente do que a lista mostra.
int countFor(
  List<TrainingSession> sessions,
  SessionFilter filter,
  DateTime now,
) {
  final hoje = _dia(now);
  return switch (filter) {
    SessionFilter.hoje => sessions.where((s) => _ehHoje(s, hoje)).length,
    SessionFilter.proximos7 =>
      sessions.where((s) => _ehProximos7(s, hoje)).length,
    SessionFilter.concluidas => sessions.where(_ehConcluida).length,
  };
}

/// Monta os blocos da lista para o filtro escolhido.
///
/// A entrada já vem ordenada pelo repository (data mais próxima primeiro, sem
/// data por último), então aqui só é preciso particionar.
List<SessionGroup> groupSessions(
  List<TrainingSession> sessions,
  SessionFilter filter,
  DateTime now,
) {
  final hoje = _dia(now);

  switch (filter) {
    case SessionFilter.hoje:
      final doDia = sessions.where((s) => _ehHoje(s, hoje)).toList();
      final outras = sessions.where((s) => _ehOutra(s, hoje)).toList();

      return [
        if (doDia.isNotEmpty)
          SessionGroup(title: 'Hoje · ${_diaEMes(hoje)}', sessions: doDia),
        if (outras.isNotEmpty)
          SessionGroup(title: 'Outras · ${outras.length}', sessions: outras),
      ];

    case SessionFilter.proximos7:
      final groups = <SessionGroup>[];
      DateTime? diaAtual;

      for (final session in sessions.where((s) => _ehProximos7(s, hoje))) {
        final dia = _dia(session.date!);
        if (dia != diaAtual) {
          diaAtual = dia;
          groups.add(SessionGroup(
            title: '${_diaDaSemana(dia)}, ${_diaEMes(dia)}',
            sessions: [],
          ));
        }
        groups.last.sessions.add(session);
      }

      return groups;

    case SessionFilter.concluidas:
      final concluidas = sessions.where(_ehConcluida).toList();
      return [
        if (concluidas.isNotEmpty)
          SessionGroup(title: 'Concluídas', sessions: concluidas),
      ];
  }
}
