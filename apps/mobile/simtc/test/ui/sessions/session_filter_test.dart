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

  test(
      'com mais de sessionsPageSize em "Hoje" e em "Outras" ao mesmo tempo, '
      'revelar mais só em "Outras" não mexe em "Hoje"', () {
    final muitasHoje = List.generate(
      15,
      (i) => session('hoje-$i', date: DateTime(2026, 9, 20, 8 + i % 12)),
    );
    final muitasOutras = List.generate(
      15,
      (i) => session('outra-$i', date: DateTime(2026, 9, 1 + i)),
    );

    final sections = buildSections(
      [...muitasHoje, ...muitasOutras],
      agora,
      {SessionBlockId.hojeOutras: 20},
    );

    final hojePrincipal = sections.first.blocks[0];
    expect(hojePrincipal.totalCount, 15);
    expect(hojePrincipal.visibleCount, sessionsPageSize);
    expect(hojePrincipal.hasMore, isTrue);

    final hojeOutras = sections.first.blocks[1];
    expect(hojeOutras.totalCount, 15);
    expect(hojeOutras.visibleCount, 15);
    expect(hojeOutras.hasMore, isFalse);
  });
}
