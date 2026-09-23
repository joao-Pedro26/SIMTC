import '../../data/models/training_session.dart';

/// Os três chips da tela 1.3. Também identificam qual seção cada chip alveja.
enum SessionFilter {
  hoje('Hoje'),
  proximos7('Próximos 7 dias'),
  concluidas('Concluídas');

  const SessionFilter(this.label);

  final String label;
}

/// Identifica um bloco que pagina de forma independente dos demais — a chave
/// que o ViewModel usa pra guardar "quantas sessões estão reveladas" por
/// bloco.
enum SessionBlockId { hojePrincipal, hojeOutras, semana, concluidas }

/// Quantas sessões um bloco revela de início, e quantas a mais a cada
/// "Ver mais". Os dados já estão todos no cache local — isto é paginação de
/// exibição, não uma nova busca.
const int sessionsPageSize = 10;

/// Um agrupamento visual dentro de um bloco. Tem título nos blocos divididos
/// por dia ("Esta semana" e "Concluídas"); em "Hoje" é um grupo único sem
/// título.
class SessionDayGroup {
  SessionDayGroup({this.title, required this.sessions});

  final String? title;
  final List<TrainingSession> sessions;
}

/// Um bloco pagina de forma independente dos outros blocos da mesma seção —
/// é por isso que "Outras" nunca engole as sessões de hoje, e vice-versa.
class SessionBlock {
  SessionBlock({
    required this.id,
    this.title,
    required this.dayGroups,
    required this.totalCount,
    required this.visibleCount,
  });

  final SessionBlockId id;

  /// Subtítulo do bloco (ex.: "Outras · 3"). Nulo quando o bloco não tem
  /// subtítulo próprio.
  final String? title;

  /// As sessões do bloco, já cortadas em `visibleCount` e organizadas em
  /// grupos por dia (um único grupo sem título em "Hoje"; um por dia em "Esta
  /// semana" e "Concluídas").
  final List<SessionDayGroup> dayGroups;

  /// Quantas sessões o bloco tem ao todo, antes de truncar.
  final int totalCount;

  /// Quantas estão reveladas agora.
  final int visibleCount;

  /// Se ainda há sessões por revelar — controla o botão "Ver mais".
  bool get hasMore => visibleCount < totalCount;
}

/// Uma das três seções de topo — sempre existe, é o alvo do chip
/// correspondente, mesmo quando não tem nenhuma sessão.
class SessionSection {
  SessionSection({
    required this.filter,
    required this.title,
    required this.blocks,
  });

  final SessionFilter filter;
  final String title;
  final List<SessionBlock> blocks;

  /// Verdadeiro quando nenhum bloco da seção tem sessão nenhuma — a tela usa
  /// isto pra saber quando mostrar a mensagem de "nada por aqui" em vez dos
  /// cards.
  bool get isEmpty => blocks.every((block) => block.totalCount == 0);
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

/// Quantas sessões o chip anuncia. Conta só o bloco principal da seção — o
/// bloco "Outras" carrega o próprio número no cabeçalho, para o chip não
/// prometer um número diferente do que a lista mostra.
int chipCountFor(
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

int _visibleCountFor(
  Map<SessionBlockId, int> visibleCounts,
  SessionBlockId id,
) =>
    visibleCounts[id] ?? sessionsPageSize;

/// Um bloco sem subdivisão por dia: as sessões truncadas viram um único
/// `SessionDayGroup` sem título.
SessionBlock _buildFlatBlock({
  required SessionBlockId id,
  String? title,
  required List<TrainingSession> all,
  required int visibleCount,
}) {
  final visible = all.take(visibleCount).toList();
  return SessionBlock(
    id: id,
    title: title,
    dayGroups: [SessionDayGroup(sessions: visible)],
    totalCount: all.length,
    visibleCount: visible.length,
  );
}

/// Um bloco dividido por dia ("Esta semana" e "Concluídas"): as sessões
/// truncadas viram um `SessionDayGroup` por dia. O `id` vem de quem chama —
/// é ele que o "Ver mais" usa para saber qual bloco revelar.
SessionBlock _buildDayBlock({
  required SessionBlockId id,
  required List<TrainingSession> all,
  required int visibleCount,
}) {
  final visible = all.take(visibleCount).toList();
  final dayGroups = <SessionDayGroup>[];
  DateTime? diaAtual;

  for (final session in visible) {
    final dia = _dia(session.date!);
    if (dia != diaAtual) {
      diaAtual = dia;
      dayGroups.add(SessionDayGroup(
        title: '${_diaDaSemana(dia)}, ${_diaEMes(dia)}',
        sessions: [],
      ));
    }
    dayGroups.last.sessions.add(session);
  }

  return SessionBlock(
    id: id,
    dayGroups: dayGroups,
    totalCount: all.length,
    visibleCount: visible.length,
  );
}

/// Monta as três seções da tela, sempre nesta ordem e sempre as três — nunca
/// escondidas, mesmo vazias. `visibleCounts` diz quantas sessões cada bloco
/// revela; um bloco sem entrada no mapa mostra as primeiras `sessionsPageSize`.
///
/// A entrada já vem ordenada pelo repository (data mais próxima primeiro, sem
/// data por último), então aqui só é preciso particionar e truncar.
List<SessionSection> buildSections(
  List<TrainingSession> sessions,
  DateTime now,
  Map<SessionBlockId, int> visibleCounts,
) {
  final hoje = _dia(now);

  final doDia = sessions.where((s) => _ehHoje(s, hoje)).toList();
  final outras = sessions.where((s) => _ehOutra(s, hoje)).toList();
  final daSemana = sessions.where((s) => _ehProximos7(s, hoje)).toList();
  final concluidas = sessions.where(_ehConcluida).toList();

  final hojePrincipal = _buildFlatBlock(
    id: SessionBlockId.hojePrincipal,
    all: doDia,
    visibleCount: _visibleCountFor(visibleCounts, SessionBlockId.hojePrincipal),
  );
  final hojeOutras = _buildFlatBlock(
    id: SessionBlockId.hojeOutras,
    title: 'Outras · ${outras.length}',
    all: outras,
    visibleCount: _visibleCountFor(visibleCounts, SessionBlockId.hojeOutras),
  );

  final semanaBlock = _buildDayBlock(
    id: SessionBlockId.semana,
    all: daSemana,
    visibleCount: _visibleCountFor(visibleCounts, SessionBlockId.semana),
  );

  final concluidasBlock = _buildDayBlock(
    id: SessionBlockId.concluidas,
    all: concluidas,
    visibleCount: _visibleCountFor(visibleCounts, SessionBlockId.concluidas),
  );

  return [
    SessionSection(
      filter: SessionFilter.hoje,
      title: 'Hoje · ${_diaEMes(hoje)}',
      blocks: [
        hojePrincipal,
        if (outras.isNotEmpty) hojeOutras,
      ],
    ),
    SessionSection(
      filter: SessionFilter.proximos7,
      title: 'Esta semana',
      blocks: [semanaBlock],
    ),
    SessionSection(
      filter: SessionFilter.concluidas,
      title: 'Concluídas',
      blocks: [concluidasBlock],
    ),
  ];
}
