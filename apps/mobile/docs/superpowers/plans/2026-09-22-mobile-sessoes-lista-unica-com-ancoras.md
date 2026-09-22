# Sessões — lista única com âncoras (correção da Tela 1.3) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir a tela "Minhas sessões" (Tela 1.3) para bater com o desenho original do canvas: os chips "Hoje / Próximos 7 dias / Concluídas" deixam de esconder/filtrar sessões e passam a ser âncoras de rolagem sobre uma lista única, com as três seções sempre visíveis e cada bloco paginado individualmente para não travar em listas grandes.

**Architecture:** `session_filter.dart` ganha uma hierarquia de dados em 3 níveis (`SessionSection` > `SessionBlock` > `SessionDayGroup`) no lugar do `SessionGroup` plano atual; o `ViewModel` guarda o estado de paginação por bloco e para de esconder seções ao trocar de filtro; a `Screen` renderiza as três seções sempre e conecta um `ScrollController` bidirecional (tocar no chip rola até a seção; rolar manualmente destaca o chip).

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4, MVVM + Repository (herdado), sem dependências novas — o scroll-to-anchor usa `Scrollable.ensureVisible` e `RenderBox`, nativos do SDK.

**Spec:** este próprio plano — a trilha mobile não usa doc de spec separado (mesma convenção das Fases 0–2). A seção "Decisões tomadas com o usuário" abaixo registra o brainstorming de 22/09/2026.

## Decisões tomadas com o usuário (22/09/2026)

O comportamento implementado na Fase 2 (chips que escondem/filtram sessões) divergiu do canvas de design (`apps/mobile/docs/design/SIMTC-Mobile.dc.html`, linhas 767–848, tela "1.3 Minhas sessões") sem que essa divergência tivesse sido discutida — foi um desvio meu ao escrever o plano da Fase 2, não uma decisão tomada com o usuário. Esta trilha corrige isso:

1. **Modelo da lista:** uma lista rolável só, com as seções Hoje / Próximos 7 dias / Concluídas sempre empilhadas e visíveis — nenhuma nunca some. Os chips viram atalho que rola até a seção correspondente, nunca escondem as outras.
2. **"Próximos 7 dias" vira um cabeçalho único "Esta semana"** (é o alvo do chip), com subcabeçalhos menores por dia dentro dele — a subdivisão por dia que já existia não vira mais seções separadas.
3. **"Outras"** (sessões sem data, ou atrasadas ainda abertas) continua dentro da seção "Hoje", no final — como já funciona hoje.
4. **Paginação por bloco:** um botão "Ver mais" no fim de cada bloco revela mais 10 sessões — os dados já estão todos no cache Drift local (a Fase 2 já limita a janela a 90 dias e sincroniza tudo antes da tela abrir), então isto é paginação de **exibição**, nunca uma nova busca de rede ou banco. 10 sessões por vez, inicial e por clique.
5. **Dentro de "Esta semana":** um bloco só — pagina a semana inteira, podendo cortar no meio de um dia (simplicidade; um consultor raramente tem mais de 10 sessões nos próximos 7 dias).
6. **Dentro de "Hoje":** o bloco principal (sessões de hoje) e o bloco "Outras" paginam **cada um separadamente** — são conceitos diferentes, e "Outras" pode acumular bastante se o consultor ficar tempo sem abrir o app; paginar junto faria sessões de hoje sumirem atrás de um acúmulo de atrasadas.
7. **Seção vazia:** sempre aparece na lista (nunca some), com uma mensagem no lugar dos cards — as três seções sempre existem, sempre na mesma ordem, então o chip sempre tem um lugar real para rolar até.
8. **Chip segue o scroll nos dois sentidos:** tocar um chip rola a lista e destaca ele; rolar manualmente com o dedo também destaca o chip da seção mais visível, mas **nunca** dispara um novo scroll — só o toque explícito rola. Durante a animação de um scroll disparado por toque, a leitura do scroll manual fica suspensa, para o chip não piscar entre seções intermediárias.

**O que não muda** (mesma regra de negócio, só muda como é exibida):
- As regras de elegibilidade por sessão (`_estaAberta`, `_ehHoje`, `_ehProximos7`, `_ehConcluida`, `_ehOutra`) continuam idênticas.
- Sessões `CANCELADO` continuam fora de tudo (decisão registrada em 20/09/2026, no plano da Fase 2).
- A janela de 90 dias e o sync do repository (Fase 2, Task 8) não são tocados.
- O número do chip continua contando **só o bloco principal** da seção — "Outras" nunca soma no chip "Hoje" (regra já existente, com uma razão declarada no código: "o chip não pode prometer um número diferente do que a lista mostra").

## Global Constraints

- Commits em português, uma linha, `tipo(escopo): mensagem`, sem ponto final, **sem `Co-Authored-By`** e sem rodapé. Um commit por task.
- `git add` sempre com caminhos explícitos. Nunca `git add -A` nem `git add .`.
- Branch `feat/mobile-app`, já ativa. Não criar branch, não fazer merge, não fazer push.
- MVVM + Repository: a `Screen` fala só com o `ViewModel`; o `ViewModel` fala só com `SessionRepository`/`ConnectivityService`.
- **Design System, sem exceção:** nenhum `Color(0xFF…)`, número mágico de espaçamento ou `TextStyle` literal fora de `lib/ui/core/theme/`. Cores por `AppColors`, espaçamento por `AppSpacing`/`AppRadius`, texto por `AppTypography`, ícones por `AppIcons`.
- `flutter analyze` termina com `No issues found!`; a suíte inteira do app (97 testes antes desta trilha) passa antes de cada commit.
- Nenhuma dependência nova em `pubspec.yaml`.
- Contratos reais apenas — nenhum campo ou endpoint não confirmado no código.
- TDD: teste falhando pelo motivo certo → implementação → teste passando.

---

### Task 1: `session_filter.dart` — estrutura de seções/blocos e `buildSections`

**Files:**
- Modify: `apps/mobile/simtc/lib/ui/sessions/session_filter.dart`
- Modify: `apps/mobile/simtc/test/ui/sessions/session_filter_test.dart`

**Interfaces:**
- Consumes: `TrainingSession` (`id`, `companyName`, `courseName`, `city`, `state`, `date`, `status`, `totalParticipants`, `assessableParticipants`, `assessedParticipants`) e `SessionStatus` de `lib/data/models/training_session.dart`.
- Produces: `SessionFilter` (mantém `hoje`/`proximos7`/`concluidas`, com `.label`); `SessionBlockId { hojePrincipal, hojeOutras, semana, concluidas }`; `sessionsPageSize` (constante pública, `10`); `SessionDayGroup { title?, sessions }`; `SessionBlock { id, title?, dayGroups, totalCount, visibleCount, hasMore }`; `SessionSection { filter, title, blocks, isEmpty }`; `buildSections(List<TrainingSession> sessions, DateTime now, Map<SessionBlockId, int> visibleCounts) -> List<SessionSection>`; `chipCountFor(List<TrainingSession> sessions, SessionFilter filter, DateTime now) -> int`. Estes nomes são contrato: a Task 2 (`ViewModel`) e a Task 3 (`Screen`) os consomem exatamente assim.

- [ ] **Step 1: Escrever os testes que falham**

Substituir o conteúdo de `test/ui/sessions/session_filter_test.dart` por:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/ui/sessions/session_filter.dart';

void main() {
  final agora = DateTime(2026, 9, 20, 9);

  TrainingSession session(
    String id, {
    DateTime? date,
    SessionStatus status = SessionStatus.planejado,
  }) {
    return TrainingSession(
      id: id,
      companyName: 'Bracell Celulose',
      courseName: 'Direção Preventiva',
      city: 'Lençóis Paulista',
      state: 'SP',
      date: date,
      status: status,
      totalParticipants: 4,
      assessableParticipants: 4,
      assessedParticipants: 1,
    );
  }

  final hoje = session('hoje', date: DateTime(2026, 9, 20, 8));
  final amanha = session('amanha', date: DateTime(2026, 9, 21, 8));
  final emSete = session('em-sete', date: DateTime(2026, 9, 27, 8));
  final emOito = session('em-oito', date: DateTime(2026, 9, 28, 8));
  final semData = session('sem-data');
  final atrasada = session('atrasada', date: DateTime(2026, 9, 10, 8));
  final concluida = session('concluida',
      date: DateTime(2026, 8, 30, 8), status: SessionStatus.concluido);

  // Na ordem que o repository entrega: data mais próxima primeiro, sem data no fim.
  final todas = [concluida, atrasada, hoje, amanha, emSete, emOito, semData];

  List<String> idsOf(SessionBlock block) =>
      block.dayGroups.expand((g) => g.sessions).map((s) => s.id).toList();

  test('as três seções sempre existem, nesta ordem, mesmo vazias', () {
    final sections = buildSections(const [], agora, const {});

    expect(
      sections.map((s) => s.filter).toList(),
      [SessionFilter.hoje, SessionFilter.proximos7, SessionFilter.concluidas],
    );
    expect(sections.every((s) => s.isEmpty), isTrue);
  });

  test(
      'Hoje traz as de hoje no bloco principal, e junta sem data e atrasadas '
      'em "Outras"', () {
    final sections = buildSections(todas, agora, const {});
    final hojeSection = sections.first;

    expect(hojeSection.title, 'Hoje · 20 set');
    expect(idsOf(hojeSection.blocks[0]), ['hoje']);
    expect(hojeSection.blocks[1].title, 'Outras · 2');
    expect(idsOf(hojeSection.blocks[1]), ['atrasada', 'sem-data']);
  });

  test('sem sessão "outra", o bloco Outras nem aparece na lista de blocos',
      () {
    final sections = buildSections([hoje], agora, const {});

    expect(sections.first.blocks, hasLength(1));
  });

  test('Esta semana é um bloco só, com um SessionDayGroup por dia', () {
    final sections = buildSections(todas, agora, const {});
    final semanaSection = sections[1];
    final semanaBlock = semanaSection.blocks.single;

    expect(semanaSection.title, 'Esta semana');
    expect(idsOf(semanaBlock), ['amanha', 'em-sete']);
    expect(
      semanaBlock.dayGroups.map((g) => g.title).toList(),
      ['Seg, 21 set', 'Dom, 27 set'],
    );
  });

  test('Concluídas ignora a data e pega só o status', () {
    final sections = buildSections(todas, agora, const {});
    final concluidasSection = sections.last;

    expect(concluidasSection.title, 'Concluídas');
    expect(idsOf(concluidasSection.blocks.single), ['concluida']);
  });

  test('sessão de hoje já concluída não aparece em Hoje, e sim em Concluídas',
      () {
    final hojeConcluida = session('hoje-ok',
        date: DateTime(2026, 9, 20, 7), status: SessionStatus.concluido);
    final sections = buildSections([hojeConcluida], agora, const {});

    expect(idsOf(sections.first.blocks[0]), isEmpty);
    expect(idsOf(sections.last.blocks.single), ['hoje-ok']);
  });

  test('sessão cancelada não entra em nenhuma seção', () {
    final cancelada = session('cancelada',
        date: DateTime(2026, 9, 20, 8), status: SessionStatus.cancelado);
    final sections = buildSections([cancelada], agora, const {});

    expect(sections.every((s) => s.isEmpty), isTrue);
  });

  test('o contador do chip conta só o bloco principal, nunca "Outras"', () {
    expect(chipCountFor(todas, SessionFilter.hoje, agora), 1);
    expect(chipCountFor(todas, SessionFilter.proximos7, agora), 2);
    expect(chipCountFor(todas, SessionFilter.concluidas, agora), 1);
  });

  test('sem visibleCounts, cada bloco mostra até sessionsPageSize sessões',
      () {
    final muitas = List.generate(
      15,
      (i) => session('c$i',
          status: SessionStatus.concluido, date: DateTime(2026, 8, i + 1)),
    );
    final sections = buildSections(muitas, agora, const {});
    final block = sections.last.blocks.single;

    expect(block.totalCount, 15);
    expect(block.visibleCount, sessionsPageSize);
    expect(block.hasMore, isTrue);
  });

  test(
      'visibleCounts revela mais sessões só no bloco pedido, sem afetar os '
      'outros', () {
    final muitasConcluidas = List.generate(
      15,
      (i) => session('c$i',
          status: SessionStatus.concluido, date: DateTime(2026, 8, i + 1)),
    );
    final sections = buildSections(
      [...muitasConcluidas, hoje],
      agora,
      {SessionBlockId.concluidas: 20},
    );

    final concluidasBlock = sections.last.blocks.single;
    expect(concluidasBlock.visibleCount, 15);
    expect(concluidasBlock.hasMore, isFalse);

    final hojeBlock = sections.first.blocks[0];
    expect(hojeBlock.visibleCount, 1);
    expect(hojeBlock.hasMore, isFalse);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `cd apps/mobile/simtc && flutter test test/ui/sessions/session_filter_test.dart`
Esperado: FAIL — `SessionBlockId`, `sessionsPageSize`, `SessionBlock`, `SessionSection`, `buildSections`, `chipCountFor` não existem ainda (`SessionGroup`/`groupSessions`/`countFor` são os únicos símbolos atuais).

- [ ] **Step 3: Substituir o conteúdo de `session_filter.dart`**

```dart
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

/// Um agrupamento visual dentro de um bloco. Só tem título em "Esta semana"
/// (um por dia); nos demais blocos é um grupo único sem título.
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
  /// grupos por dia (um único grupo sem título, exceto em "Esta semana").
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

/// O bloco de "Esta semana": as sessões truncadas se dividem em um
/// `SessionDayGroup` por dia.
SessionBlock _buildWeekBlock({
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
    id: SessionBlockId.semana,
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

  final semanaBlock = _buildWeekBlock(
    all: daSemana,
    visibleCount: _visibleCountFor(visibleCounts, SessionBlockId.semana),
  );

  final concluidasBlock = _buildFlatBlock(
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
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `cd apps/mobile/simtc && flutter test test/ui/sessions/session_filter_test.dart`
Esperado: PASS, 11 testes.

- [ ] **Step 5: Rodar o analyze**

Run: `cd apps/mobile/simtc && flutter analyze`
Esperado: `No issues found!` (o arquivo antigo `SessionGroup`/`groupSessions`/`countFor` foi totalmente substituído — nada mais no repositório os referencia ainda, já que as Tasks 2 e 3 são o que os consome, e ainda não rodaram).

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/sessions/session_filter.dart apps/mobile/simtc/test/ui/sessions/session_filter_test.dart
git commit -m "feat(mobile): estrutura sessoes em secoes e blocos paginados por bloco"
```

---

### Task 2: `SessionsListViewModel` — `sections`, `counts` via `chipCountFor`, `revealMore`

**Files:**
- Modify: `apps/mobile/simtc/lib/ui/sessions/sessions_list_viewmodel.dart`
- Modify: `apps/mobile/simtc/test/ui/sessions/sessions_list_viewmodel_test.dart`

**Interfaces:**
- Consumes: `buildSections`, `chipCountFor`, `SessionBlockId`, `sessionsPageSize`, `SessionSection`, `SessionFilter` da Task 1; `SessionRepository.watchSessions()/watchLastSyncedAt()/syncAll()`; `ConnectivityService.onReconnected`; `Result`/`Success`/`Failure` de `lib/utils/result.dart`.
- Produces: `sections` (getter, `List<SessionSection>`, substitui o antigo `groups`); `revealMore(SessionBlockId id)` (novo método). Mantém sem mudança de assinatura: `filter`, `setFilter(SessionFilter)`, `counts` (`Map<SessionFilter, int>`), `isLoading`, `isRefreshing`, `errorMessage`, `lastSyncedAt`, `clearError()`, `refresh()`, `init()`, `dispose()`. `sections` e `revealMore` são contrato: a Task 3 (`Screen`) os consome exatamente assim.

- [ ] **Step 1: Escrever os testes que falham**

Substituir o conteúdo de `test/ui/sessions/sessions_list_viewmodel_test.dart` por:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/sessions/session_filter.dart';
import 'package:simtc/ui/sessions/sessions_list_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

/// Conectividade de mentira: o serviço real conversa com o plugin de
/// plataforma, que não existe num teste de unidade.
class _FakeConnectivity extends ConnectivityService {
  final _reconnected = StreamController<void>.broadcast();

  @override
  Stream<void> get onReconnected => _reconnected.stream;

  void reconnect() => _reconnected.add(null);

  @override
  void dispose() {
    _reconnected.close();
    super.dispose();
  }
}

void main() {
  late _MockSessionRepository repository;
  late _FakeConnectivity connectivity;
  late StreamController<List<TrainingSession>> sessions;

  final agora = DateTime(2026, 9, 20, 9);

  TrainingSession session(String id, {DateTime? date, SessionStatus? status}) {
    return TrainingSession(
      id: id,
      companyName: 'Bracell Celulose',
      courseName: 'Direção Preventiva',
      city: 'Lençóis Paulista',
      state: 'SP',
      date: date,
      status: status ?? SessionStatus.planejado,
      totalParticipants: 4,
      assessableParticipants: 4,
      assessedParticipants: 1,
    );
  }

  SessionsListViewModel build() => SessionsListViewModel(
        repository: repository,
        connectivity: connectivity,
        now: () => agora,
      );

  SessionBlock blockOf(
    SessionsListViewModel vm,
    SessionFilter filter, {
    int index = 0,
  }) =>
      vm.sections.firstWhere((s) => s.filter == filter).blocks[index];

  setUp(() {
    repository = _MockSessionRepository();
    connectivity = _FakeConnectivity();
    sessions = StreamController<List<TrainingSession>>.broadcast();

    when(repository.watchSessions).thenAnswer((_) => sessions.stream);
    when(repository.watchLastSyncedAt)
        .thenAnswer((_) => Stream.value(DateTime(2026, 9, 20, 8)));
    when(repository.syncAll).thenAnswer((_) async => const Success(1));
  });

  tearDown(() {
    sessions.close();
    connectivity.dispose();
  });

  test('começa carregando e sai do carregamento na primeira emissão', () async {
    final viewModel = build()..init();
    expect(viewModel.isLoading, isTrue);

    sessions.add([session('hoje', date: DateTime(2026, 9, 20, 8))]);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isLoading, isFalse);
    expect(
      blockOf(viewModel, SessionFilter.hoje).dayGroups.single.sessions.single.id,
      'hoje',
    );
  });

  test('sincroniza sozinho ao abrir', () async {
    build().init();
    await Future<void>.delayed(Duration.zero);

    verify(repository.syncAll).called(1);
  });

  test('sincroniza de novo quando a conexão volta', () async {
    build().init();
    await Future<void>.delayed(Duration.zero);

    connectivity.reconnect();
    await Future<void>.delayed(Duration.zero);

    verify(repository.syncAll).called(2);
  });

  test('os contadores dos chips não dependem do filtro escolhido', () async {
    final viewModel = build()..init();
    sessions.add([
      session('hoje', date: DateTime(2026, 9, 20, 8)),
      session('amanha', date: DateTime(2026, 9, 21, 8)),
      session('ok', status: SessionStatus.concluido),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.counts[SessionFilter.hoje], 1);
    expect(viewModel.counts[SessionFilter.proximos7], 1);
    expect(viewModel.counts[SessionFilter.concluidas], 1);
  });

  test('trocar o filtro não esconde nenhuma seção — as três continuam com tudo',
      () async {
    final viewModel = build()..init();
    sessions.add([session('amanha', date: DateTime(2026, 9, 21, 8))]);
    await Future<void>.delayed(Duration.zero);

    expect(
      blockOf(viewModel, SessionFilter.proximos7).dayGroups.single.sessions.single.id,
      'amanha',
    );

    viewModel.setFilter(SessionFilter.proximos7);

    // A seção continua com a mesma sessão — trocar o filtro só muda qual
    // seção está "em foco", nunca esconde nenhuma.
    expect(
      blockOf(viewModel, SessionFilter.proximos7).dayGroups.single.sessions.single.id,
      'amanha',
    );
    expect(viewModel.filter, SessionFilter.proximos7);
    verify(repository.syncAll).called(1);
  });

  test('revealMore aumenta as sessões visíveis só no bloco pedido, sem nova rede',
      () async {
    final viewModel = build()..init();
    sessions.add(List.generate(
      15,
      (i) => session('c$i',
          status: SessionStatus.concluido, date: DateTime(2026, 8, i + 1)),
    ));
    await Future<void>.delayed(Duration.zero);

    final antes = blockOf(viewModel, SessionFilter.concluidas);
    expect(antes.visibleCount, sessionsPageSize);
    expect(antes.hasMore, isTrue);

    viewModel.revealMore(SessionBlockId.concluidas);

    final depois = blockOf(viewModel, SessionFilter.concluidas);
    expect(depois.visibleCount, 15);
    expect(depois.hasMore, isFalse);
    verify(repository.syncAll).called(1); // não chamou de novo
  });

  test('falha no refresh vira mensagem, sem apagar a lista', () async {
    final viewModel = build()..init();
    sessions.add([session('hoje', date: DateTime(2026, 9, 20, 8))]);
    await Future<void>.delayed(Duration.zero);

    when(repository.syncAll)
        .thenAnswer((_) async => Failure(Exception('sem rede'), 'Sem conexão.'));

    await viewModel.refresh();

    expect(viewModel.errorMessage, 'Sem conexão.');
    expect(
      blockOf(viewModel, SessionFilter.hoje).dayGroups.single.sessions,
      hasLength(1),
    );
  });

  test(
      'cache vazio e nunca sincronizado mantém o carregamento até o primeiro '
      'sync terminar', () async {
    // Cenário do primeiro login: o cache Drift está genuinamente vazio, o
    // stream emite `[]` na hora, e sem esta distinção a tela afirmaria "sem
    // sessão" enquanto ainda está baixando em 4G ruim.
    final syncCompleter = Completer<Result<int>>();
    when(repository.syncAll).thenAnswer((_) => syncCompleter.future);
    when(repository.watchLastSyncedAt).thenAnswer((_) => Stream.value(null));

    final viewModel = build()..init();
    sessions.add(const []);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isLoading, isTrue,
        reason: 'o primeiro sync ainda está em andamento');

    syncCompleter.complete(const Success(0));
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isLoading, isFalse,
        reason: 'o sync terminou; agora é um cache genuinamente vazio');
  });

  test(
      'uma exceção que escapa do Result não trava _isRefreshing: o próximo '
      'refresh funciona', () async {
    when(repository.syncAll).thenThrow(StateError('bug inesperado'));

    final viewModel = build()..init();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isRefreshing, isFalse);

    when(repository.syncAll).thenAnswer((_) async => const Success(1));
    await viewModel.refresh();

    verify(repository.syncAll).called(2);
    expect(viewModel.isRefreshing, isFalse);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `cd apps/mobile/simtc && flutter test test/ui/sessions/sessions_list_viewmodel_test.dart`
Esperado: FAIL — `sections`/`revealMore` não existem no `ViewModel` atual (que ainda expõe `groups`).

- [ ] **Step 3: Editar `sessions_list_viewmodel.dart`**

Substituir o conteúdo do arquivo por:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/training_session.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../utils/result.dart';
import 'session_filter.dart';

/// Estado da tela 1.3 "Minhas sessões".
///
/// A lista nunca vem da resposta HTTP: chega pelo stream do cache. O sync é um
/// efeito colateral que atualiza o cache — se falhar, a tela continua com o que
/// tem e só ganha uma mensagem.
///
/// As três seções (Hoje, Esta semana, Concluídas) estão sempre todas
/// presentes — os chips não filtram, só marcam qual seção está em foco (a
/// tela usa isso pra saber pra onde rolar e qual chip destacar).
class SessionsListViewModel extends ChangeNotifier {
  SessionsListViewModel({
    required SessionRepository repository,
    required ConnectivityService connectivity,
    DateTime Function()? now,
  })  : _repository = repository,
        _connectivity = connectivity,
        _now = now ?? DateTime.now;

  final SessionRepository _repository;
  final ConnectivityService _connectivity;
  final DateTime Function() _now;

  StreamSubscription<List<TrainingSession>>? _sessionsSubscription;
  StreamSubscription<DateTime?>? _syncedAtSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  List<TrainingSession> _sessions = const [];
  SessionFilter _filter = SessionFilter.hoje;
  final Map<SessionBlockId, int> _visibleCounts = {};
  bool _hasLoadedOnce = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  DateTime? _lastSyncedAt;

  SessionFilter get filter => _filter;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  /// Quando o cache foi atualizado pela última vez — a faixa de offline usa
  /// isso para dizer a idade do que está na tela.
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Antes da primeira leitura do cache, é sempre carregamento. Depois disso,
  /// mesmo vazia, a tela já sabe o que mostrar — e skeleton por cima de dados
  /// velhos esconderia justamente o que o consultor precisa ver quando está
  /// offline. A exceção é o cache vazio que nunca foi sincronizado (primeiro
  /// login): aí o stream do Drift emite `[]` na hora, e sem esta distinção a
  /// tela afirmaria "sem sessão nenhuma" enquanto o primeiro sync ainda
  /// baixa em 4G ruim — então o carregamento continua até ele terminar.
  bool get isLoading =>
      !_hasLoadedOnce ||
      (_sessions.isEmpty && _lastSyncedAt == null && _isRefreshing);

  /// As três seções, sempre nesta ordem, sempre as três — nunca escondidas.
  List<SessionSection> get sections =>
      buildSections(_sessions, _now(), _visibleCounts);

  Map<SessionFilter, int> get counts => {
        for (final filter in SessionFilter.values)
          filter: chipCountFor(_sessions, filter, _now()),
      };

  /// Assina o cache e dispara o primeiro sync. Chamado uma vez pela tela.
  void init() {
    _sessionsSubscription ??= _repository.watchSessions().listen((sessions) {
      _sessions = sessions;
      _hasLoadedOnce = true;
      notifyListeners();
    });

    _syncedAtSubscription ??= _repository.watchLastSyncedAt().listen((value) {
      _lastSyncedAt = value;
      notifyListeners();
    });

    // A volta da conexão atualiza a agenda sem o consultor pedir: ele costuma
    // sair da área sem sinal já dentro do pátio, com o celular no bolso.
    _reconnectSubscription ??=
        _connectivity.onReconnected.listen((_) => refresh());

    unawaited(refresh());
  }

  /// Marca qual seção está em foco — não esconde nem revela nenhuma sessão,
  /// as três seções continuam sempre visíveis. A tela usa isto pra saber
  /// qual chip destacar; quem decide rolar a lista é a tela, não o VM.
  void setFilter(SessionFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  /// Revela mais `sessionsPageSize` sessões no bloco pedido. Os dados já
  /// estão todos em memória — isto é paginação de exibição, não busca nova.
  void revealMore(SessionBlockId id) {
    _visibleCounts[id] =
        (_visibleCounts[id] ?? sessionsPageSize) + sessionsPageSize;
    notifyListeners();
  }

  /// Puxar para atualizar, abertura da tela e volta da conexão caem todos aqui.
  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.syncAll();
      if (result case Failure(message: final message)) {
        _errorMessage = message ?? 'Não foi possível atualizar as sessões.';
      }
    } catch (_) {
      // `syncAll` já devolve `Result` para todo erro esperado; isto é uma
      // rede de segurança contra o que escapar dele. Sem ela, `_isRefreshing`
      // travaria em `true` e todo refresh seguinte (puxar, voltar a conexão,
      // reabrir a tela) cairia no guard-clause de início deste método.
      _errorMessage = 'Não foi possível atualizar as sessões.';
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    _syncedAtSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `cd apps/mobile/simtc && flutter test test/ui/sessions/sessions_list_viewmodel_test.dart`
Esperado: PASS, 9 testes.

- [ ] **Step 5: Rodar o analyze**

Run: `cd apps/mobile/simtc && flutter analyze`
Esperado: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/sessions/sessions_list_viewmodel.dart apps/mobile/simtc/test/ui/sessions/sessions_list_viewmodel_test.dart
git commit -m "feat(mobile): viewmodel para de filtrar secoes e ganha revealMore"
```

---

### Task 3: `SessionsScreen` — renderiza as três seções sempre visíveis, com paginação por bloco

Sem scroll-to-anchor ainda (isso é a Task 4). Esta task troca a renderização de "grupos do filtro atual" para "as três seções, sempre", com o botão "Ver mais" por bloco e a mensagem de seção vazia.

**Files:**
- Modify: `apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart`
- Modify: `apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: `SessionsListViewModel.sections/counts/filter/setFilter/revealMore/isLoading/isRefreshing/errorMessage/clearError/lastSyncedAt/refresh` (Task 2); `SessionSection/SessionBlock/SessionDayGroup/SessionFilter` (Task 1); componentes existentes `SessionCard`, `StatusChip`, `FilterChipBar`/`FilterChipData`, `PillNavBar`/`PillNavItem`, `SkeletonBox`, `ConnectivityBanner`, `InlineNotice`; tokens `AppColors`/`AppSpacing`/`AppTypography`/`AppIcons`.
- Produces: `SessionsScreen` (sem mudança de API pública — StatefulWidget sem parâmetros).

- [ ] **Step 1: Escrever os testes que falham**

Substituir o conteúdo de `test/ui/sessions/sessions_screen_test.dart` por:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/sessions/sessions_screen.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockSessionRepository repository;
  late _MockAuthRepository auth;
  late StreamController<List<TrainingSession>> sessions;
  late ConnectivityService connectivity;

  const consultor = AuthUser(
    id: 'u1',
    name: 'Carla Souza',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c1',
  );

  TrainingSession hoje() {
    return TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell Celulose',
      courseName: 'Direção Preventiva',
      city: 'Lençóis Paulista',
      state: 'SP',
      date: DateTime.now(),
      status: SessionStatus.emAndamento,
      totalParticipants: 8,
      assessableParticipants: 8,
      assessedParticipants: 2,
    );
  }

  setUp(() {
    repository = _MockSessionRepository();
    auth = _MockAuthRepository();
    sessions = StreamController<List<TrainingSession>>.broadcast();
    connectivity = ConnectivityService();

    when(repository.watchSessions).thenAnswer((_) => sessions.stream);
    when(repository.watchLastSyncedAt).thenAnswer((_) => Stream.value(null));
    when(repository.syncAll).thenAnswer((_) async => const Success(0));
    when(() => auth.currentUser).thenReturn(consultor);
  });

  tearDown(() {
    sessions.close();
    connectivity.dispose();
  });

  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: repository),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: const MaterialApp(home: SessionsScreen()),
      ),
    );
  }

  String titleText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('sessions-title'))).data!;

  testWidgets('mostra skeleton antes da primeira leitura do cache',
      (tester) async {
    await pump(tester);
    await tester.pump();

    expect(find.byKey(const Key('sessions-skeleton')), findsOneWidget);
    expect(find.byType(SessionCard), findsNothing);
  });

  testWidgets('mostra a sessão de hoje com o progresso', (tester) async {
    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    expect(find.byType(SessionCard), findsOneWidget);
    expect(find.text('Bracell Celulose'), findsOneWidget);
    expect(find.text('2 de 8 avaliados'), findsOneWidget);
  });

  testWidgets('saúda o consultor pelo primeiro nome e usa o título dele',
      (tester) async {
    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    expect(find.textContaining('Carla'), findsOneWidget);
    expect(titleText(tester), 'Minhas sessões');
  });

  testWidgets('para ADMIN o título é "Sessões"', (tester) async {
    when(() => auth.currentUser).thenReturn(const AuthUser(
      id: 'u2',
      name: 'Rita Alves',
      email: 'rita@simtc.com.br',
      role: AppUserRole.admin,
    ));

    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    expect(titleText(tester), 'Sessões');
  });

  testWidgets('falha ao atualizar aparece num SnackBar, sem apagar a lista',
      (tester) async {
    when(repository.syncAll)
        .thenAnswer((_) async => Failure(Exception('sem rede'), 'Sem conexão.'));

    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump(); // entrega do stream e disparo do listener
    await tester.pump(); // post-frame callback que mostra o SnackBar
    await tester.pump(const Duration(milliseconds: 750)); // animação de entrada

    expect(find.text('Sem conexão.'), findsOneWidget);
    expect(find.byType(SessionCard), findsOneWidget);
  });

  testWidgets('cache vazio mostra as três seções vazias, não o skeleton',
      (tester) async {
    // `watchLastSyncedAt` não nulo garante que este teste cobre o cache
    // genuinamente vazio (já sincronizado antes, sem sessão nenhuma) — e não
    // o caso "nunca sincronizou", que fica de propósito no skeleton até o
    // primeiro sync terminar (ver `sessions_list_viewmodel_test.dart`).
    when(repository.watchLastSyncedAt)
        .thenAnswer((_) => Stream.value(DateTime(2026, 9, 20, 8)));

    await pump(tester);
    sessions.add(const []);
    await tester.pump();

    expect(find.byKey(const Key('sessions-skeleton')), findsNothing);
    expect(find.text('Nenhuma sessão para hoje.'), findsOneWidget);
    expect(find.text('Nada agendado para os próximos 7 dias.'), findsOneWidget);
    expect(find.text('Nenhuma sessão concluída ainda.'), findsOneWidget);
  });

  testWidgets(
      'sessões de hoje e da semana aparecem juntas, sem precisar trocar de chip',
      (tester) async {
    final amanha = TrainingSession(
      id: 'sess-2',
      companyName: 'Suzano Papel',
      courseName: 'Operação de Empilhadeira',
      city: 'Bauru',
      state: 'SP',
      date: DateTime.now().add(const Duration(days: 1)),
      status: SessionStatus.planejado,
      totalParticipants: 3,
      assessableParticipants: 3,
      assessedParticipants: 0,
    );

    await pump(tester);
    sessions.add([hoje(), amanha]);
    await tester.pump();

    expect(find.text('Bracell Celulose'), findsOneWidget);
    expect(find.text('Suzano Papel'), findsOneWidget);
  });

  testWidgets(
      'bloco com mais de 10 sessões mostra "Ver mais", que revela o resto',
      (tester) async {
    final muitas = List.generate(15, (i) {
      return TrainingSession(
        id: 'c$i',
        companyName: 'Empresa $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime(2026, 8, i % 28 + 1),
        status: SessionStatus.concluido,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 1,
      );
    });

    await pump(tester);
    sessions.add(muitas);
    await tester.pump();

    expect(find.text('Empresa 0'), findsOneWidget);
    expect(find.text('Empresa 10'), findsNothing);
    expect(find.byKey(const ValueKey('ver-mais-concluidas')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ver-mais-concluidas')));
    await tester.pump();

    expect(find.text('Empresa 10'), findsOneWidget);
    expect(find.byKey(const ValueKey('ver-mais-concluidas')), findsNothing);
  });

  testWidgets(
      'puxar uma lista mais curta que a tela ainda dispara a atualização',
      (tester) async {
    // Viewport bem maior que uma sessão só garante que a lista fica mais
    // curta que a tela — o caso do dia a dia do filtro "Hoje", com uma ou
    // duas sessões.
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // init() já chamou syncAll uma vez; o arrasto precisa chamar de novo.
    verify(repository.syncAll).called(2);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `cd apps/mobile/simtc && flutter test test/ui/sessions/sessions_screen_test.dart`
Esperado: FAIL — a tela ainda usa `viewModel.groups` (que não existe mais desde a Task 2), e não tem o botão "Ver mais" nem a chave `ver-mais-concluidas`.

- [ ] **Step 3: Editar `sessions_screen.dart`**

Substituir os métodos `_buildFilters`, `_buildBody`, `_buildGroup` (remover) e `_buildEmptyState` (remover) pelo bloco abaixo. O restante do arquivo (`_buildScaffold`, `_buildHeader`, `_offlineMessage`, `_buildSyncIndicator`, `_greeting`, `_buildCard`, `_accentFor`, `_toneFor`, `_iconFor`, `_buildSkeleton`, `_buildNavBar`, os imports, e o topo da classe) não muda nesta task.

```dart
  Widget _buildFilters(SessionsListViewModel viewModel) {
    final counts = viewModel.counts;

    return Container(
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: FilterChipBar(
        items: [
          for (final filter in SessionFilter.values)
            FilterChipData(label: filter.label, count: counts[filter]),
        ],
        selectedIndex: SessionFilter.values.indexOf(viewModel.filter),
        onSelect: (index) => viewModel.setFilter(SessionFilter.values[index]),
      ),
    );
  }

  Widget _buildBody(SessionsListViewModel viewModel) {
    if (viewModel.isLoading) return _buildSkeleton();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: viewModel.refresh,
      child: ListView(
        // Explícito por segurança: um `ListView` sem `controller` já é
        // "primary" e ganha essa física por padrão, mas deixar implícito
        // depende desse detalhe do framework.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.huge * 2,
        ),
        children: [
          for (final section in viewModel.sections)
            ..._buildSection(viewModel, section),
        ],
      ),
    );
  }

  /// As três seções sempre aparecem, sempre nesta ordem — os chips só rolam
  /// até elas, nunca escondem nenhuma. Cada bloco dentro da seção pagina de
  /// forma independente dos demais.
  List<Widget> _buildSection(
    SessionsListViewModel viewModel,
    SessionSection section,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.sm + 2,
        ),
        child: Text(
          section.title,
          style: AppTypography.meta.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      if (section.isEmpty)
        _buildSectionEmpty(section.filter)
      else
        for (final block in section.blocks) ..._buildBlock(viewModel, block),
    ];
  }

  List<Widget> _buildBlock(SessionsListViewModel viewModel, SessionBlock block) {
    return [
      if (block.title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xs,
          ),
          child: Text(
            block.title!,
            style: AppTypography.meta.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      for (final dayGroup in block.dayGroups) ..._buildDayGroup(dayGroup),
      if (block.hasMore) _buildRevealMoreButton(viewModel, block),
    ];
  }

  List<Widget> _buildDayGroup(SessionDayGroup dayGroup) {
    return [
      if (dayGroup.title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xs,
          ),
          child: Text(dayGroup.title!, style: AppTypography.meta),
        ),
      for (final session in dayGroup.sessions) _buildCard(session),
    ];
  }

  Widget _buildRevealMoreButton(
    SessionsListViewModel viewModel,
    SessionBlock block,
  ) {
    return Padding(
      key: ValueKey('ver-mais-${block.id.name}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Center(
        child: TextButton(
          onPressed: () => viewModel.revealMore(block.id),
          child: Text('Ver mais', style: AppTypography.link),
        ),
      ),
    );
  }

  /// A seção nunca some, mesmo vazia — é o que garante que o chip sempre tem
  /// um lugar real pra rolar até.
  Widget _buildSectionEmpty(SessionFilter filter) {
    final message = switch (filter) {
      SessionFilter.hoje => 'Nenhuma sessão para hoje.',
      SessionFilter.proximos7 => 'Nada agendado para os próximos 7 dias.',
      SessionFilter.concluidas => 'Nenhuma sessão concluída ainda.',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: InlineNotice(icon: AppIcons.sessions, message: message),
    );
  }
```

A chave `ValueKey('ver-mais-${block.id.name}')` fica no `Padding` (não no `TextButton`) porque `find.byKey` em `_buildRevealMoreButton` precisa achar exatamente um widget por bloco — como cada `SessionBlockId` só aparece uma vez na árvore por vez, isso não colide.

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `cd apps/mobile/simtc && flutter test test/ui/sessions/sessions_screen_test.dart`
Esperado: PASS, 9 testes.

- [ ] **Step 5: Rodar a suíte inteira e o analyze**

Run: `cd apps/mobile/simtc && flutter analyze && flutter test`
Esperado: `No issues found!`, todos os testes passando (94 = 97 anteriores − 3 testes substituídos nesta task + 9 novos... na prática, rode e confira o total; o que importa é 0 falhas).

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart
git commit -m "feat(mobile): tela renderiza as tres secoes sempre visiveis com ver mais"
```

---

### Task 4: Scroll-to-anchor bidirecional

**Files:**
- Modify: `apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart`
- Modify: `apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: `SessionFilter`, `SessionsListViewModel.setFilter/filter` (Tasks 1–2); `Scrollable.ensureVisible`, `RenderBox`, `ScrollController` do SDK do Flutter.
- Produces: nenhuma API nova exposta fora da classe — o comportamento é só de UI.

- [ ] **Step 1: Escrever os testes que falham**

Acrescentar ao final de `test/ui/sessions/sessions_screen_test.dart` (antes do `}` de fechamento do `main`):

```dart
  bool isChipSelected(WidgetTester tester, String label) {
    final inkWell = tester.widget<InkWell>(find.widgetWithText(InkWell, label));
    final container = inkWell.child! as Container;
    final decoration = container.decoration! as BoxDecoration;
    return decoration.color == AppColors.primary;
  }

  testWidgets('tocar num chip rola até a seção correspondente', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final muitasHoje = List.generate(
      20,
      (i) => TrainingSession(
        id: 'h$i',
        companyName: 'Empresa Hoje $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now(),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );
    final concluida = TrainingSession(
      id: 'concluida-1',
      companyName: 'Empresa Concluída',
      courseName: 'Curso',
      city: 'Bauru',
      state: 'SP',
      date: DateTime(2026, 8, 1),
      status: SessionStatus.concluido,
      totalParticipants: 1,
      assessableParticipants: 1,
      assessedParticipants: 1,
    );

    await pump(tester);
    sessions.add([...muitasHoje, concluida]);
    await tester.pump();

    // Antes de tocar, as 10 primeiras sessões de hoje já preenchem a tela —
    // a seção Concluídas está fora da área visível.
    expect(find.text('Empresa Concluída'), findsNothing);

    await tester.tap(find.widgetWithText(InkWell, 'Concluídas'));
    await tester.pumpAndSettle();

    expect(find.text('Empresa Concluída'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Empresa Concluída')).dy, lessThan(200));
  });

  testWidgets('rolar manualmente destaca o chip da seção mais visível',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final muitasHoje = List.generate(
      15,
      (i) => TrainingSession(
        id: 'h$i',
        companyName: 'Empresa Hoje $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now(),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );
    final concluida = TrainingSession(
      id: 'concluida-1',
      companyName: 'Empresa Concluída',
      courseName: 'Curso',
      city: 'Bauru',
      state: 'SP',
      date: DateTime(2026, 8, 1),
      status: SessionStatus.concluido,
      totalParticipants: 1,
      assessableParticipants: 1,
      assessedParticipants: 1,
    );

    await pump(tester);
    sessions.add([...muitasHoje, concluida]);
    await tester.pump();

    expect(isChipSelected(tester, 'Hoje'), isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pump();

    expect(isChipSelected(tester, 'Concluídas'), isTrue);
  });

  testWidgets(
      'depois de rolar manualmente, tocar num chip ainda rola pra seção certa '
      'sem piscar', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final muitasHoje = List.generate(
      15,
      (i) => TrainingSession(
        id: 'h$i',
        companyName: 'Empresa Hoje $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now(),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );

    await pump(tester);
    sessions.add(muitasHoje);
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pump();

    await tester.tap(find.widgetWithText(InkWell, 'Hoje'));
    await tester.pumpAndSettle();

    expect(isChipSelected(tester, 'Hoje'), isTrue);
    expect(find.text('Empresa Hoje 0'), findsOneWidget);
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `cd apps/mobile/simtc && flutter test test/ui/sessions/sessions_screen_test.dart`
Esperado: FAIL — tocar num chip hoje só muda `viewModel.filter` (a Task 3 nem chegou a esconder nem a rolar nada), então nenhum scroll acontece e "Empresa Concluída" continua fora da viewport nos três testes novos.

- [ ] **Step 3: Editar `sessions_screen.dart`**

No topo da classe `_SessionsScreenState`, logo após a declaração de `_viewModel`, acrescentar:

```dart
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  final Map<SessionFilter, GlobalKey> _sectionKeys = {
    for (final filter in SessionFilter.values) filter: GlobalKey(),
  };

  /// Suspende a leitura do scroll manual enquanto um toque de chip está
  /// animando o `Scrollable.ensureVisible` — sem isso, o chip picaria entre
  /// seções intermediárias até o scroll assentar no destino.
  bool _isProgrammaticScroll = false;
```

Em `initState`, acrescentar a assinatura do listener de scroll:

```dart
  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_showErrorWhenItArrives);
    _scrollController.addListener(_updateActiveChipFromScroll);
  }
```

Em `dispose`, remover o listener e descartar o controller antes do resto:

```dart
  @override
  void dispose() {
    _scrollController.removeListener(_updateActiveChipFromScroll);
    _scrollController.dispose();
    _viewModel.removeListener(_showErrorWhenItArrives);
    _viewModel.dispose();
    super.dispose();
  }
```

Acrescentar os dois métodos de scroll (posição sugerida: logo antes de `_buildScaffold`):

```dart
  /// Toque num chip: marca a seção correspondente e rola até ela.
  Future<void> _onChipTap(SessionFilter filter) async {
    _viewModel.setFilter(filter);

    final target = _sectionKeys[filter]?.currentContext;
    if (target == null) return;

    _isProgrammaticScroll = true;
    await Scrollable.ensureVisible(
      target,
      alignment: 0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _isProgrammaticScroll = false;
  }

  /// Enquanto o dedo rola a lista (sem ter tocado em nenhum chip), decide
  /// qual seção está mais visível — a última cujo topo já passou do topo da
  /// área rolável — e destaca o chip correspondente. Nunca dispara um novo
  /// scroll: só o toque explícito faz isso, senão vira loop.
  void _updateActiveChipFromScroll() {
    if (_isProgrammaticScroll) return;

    final listBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (listBox == null || !listBox.attached) return;
    final activationOffset = listBox.localToGlobal(Offset.zero).dy;

    SessionFilter? active;
    for (final filter in SessionFilter.values) {
      final box = _sectionKeys[filter]?.currentContext?.findRenderObject()
          as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= activationOffset) {
        active = filter;
      }
    }

    if (active != null) _viewModel.setFilter(active);
  }
```

Em `_buildFilters`, trocar `onSelect` para chamar `_onChipTap`:

```dart
        onSelect: (index) => _onChipTap(SessionFilter.values[index]),
```

Em `_buildBody`, dar ao `ListView` o `key` e o `controller`:

```dart
      child: ListView(
        key: _listKey,
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
```

Em `_buildSection`, dar ao `Padding` do cabeçalho o `GlobalKey` da seção:

```dart
      Padding(
        key: _sectionKeys[section.filter],
        padding: const EdgeInsets.fromLTRB(
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `cd apps/mobile/simtc && flutter test test/ui/sessions/sessions_screen_test.dart`
Esperado: PASS, 12 testes.

- [ ] **Step 5: Rodar a suíte inteira e o analyze**

Run: `cd apps/mobile/simtc && flutter analyze && flutter test`
Esperado: `No issues found!`, todos os testes passando.

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart
git commit -m "feat(mobile): chips viram ancoras de rolagem nos dois sentidos"
```

---

### Task 5: Validação no aparelho físico

Não é código — é o roteiro manual que só o usuário pode rodar. Mesma mecânica de sync/rede já validada na Fase 2 (nada muda aqui); o roteiro cobre só o que este plano mudou.

**Files:** nenhum.

- [ ] **Step 1: Build e instalação**

Run: `cd apps/backend && npm run start:dev` (terminal 1)
Run: `adb reverse tcp:3001 tcp:3001` (com o aparelho conectado)
Run: `cd apps/mobile/simtc && flutter run -d <ID_DO_APARELHO>` (descobrir o id com `flutter devices`)

Sem `--dart-define` — o padrão já aponta para o backend local.

- [ ] **Step 2: Roteiro**

- [ ] as três seções (Hoje, Esta semana, Concluídas) aparecem sempre, nesta ordem, mesmo antes de tocar em qualquer chip;
- [ ] uma seção sem sessão nenhuma mostra a mensagem própria, nunca some da tela;
- [ ] tocar em cada chip rola suavemente até a seção correspondente;
- [ ] rolar a lista com o dedo, devagar, passando pelas três seções, destaca o chip certo em cada momento — sem nenhum salto ou volta de scroll;
- [ ] uma seção com mais de 10 sessões mostra "Ver mais"; tocar revela mais 10; a seção some quando não há mais nada a revelar;
- [ ] dentro de "Hoje", se houver sessões de hoje e sessões em "Outras" ao mesmo tempo, cada bloco tem seu próprio "Ver mais" (não compartilham);
- [ ] dentro de "Esta semana", cada dia aparece com seu próprio subtítulo (ex.: "Seg, 22 set"), dentro do cabeçalho único "Esta semana";
- [ ] puxar para atualizar (pull-to-refresh) continua funcionando com a lista no meio do scroll;
- [ ] sessões `CANCELADO` continuam fora de tudo (nenhuma seção, nenhum "Ver mais" as revela);
- [ ] nenhuma sessão que aparecia antes desta mudança sumiu — some só o comportamento de esconder por filtro.

## Pendências levadas para fases seguintes

- Nenhuma identificada até aqui. Se a validação em aparelho revelar algo, registrar aqui antes de fechar o plano.
