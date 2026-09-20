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

  List<String> idsOf(List<SessionGroup> groups) =>
      groups.expand((g) => g.sessions).map((s) => s.id).toList();

  test('Hoje traz as de hoje e junta sem data e atrasadas em "Outras"', () {
    final groups = groupSessions(todas, SessionFilter.hoje, agora);

    expect(groups.first.title, 'Hoje · 20 set');
    expect(groups.first.sessions.map((s) => s.id).toList(), ['hoje']);
    expect(groups.last.title, 'Outras · 2');
    expect(groups.last.sessions.map((s) => s.id).toList(),
        ['atrasada', 'sem-data']);
  });

  test('Próximos 7 dias vai de amanhã até o sétimo dia, um grupo por dia', () {
    final groups = groupSessions(todas, SessionFilter.proximos7, agora);

    expect(idsOf(groups), ['amanha', 'em-sete']);
    expect(groups.first.title, 'Seg, 21 set');
  });

  test('Concluídas ignora a data e pega só o status', () {
    final groups = groupSessions(todas, SessionFilter.concluidas, agora);

    expect(groups.single.title, 'Concluídas');
    expect(idsOf(groups), ['concluida']);
  });

  test('sessão de hoje já concluída não aparece em Hoje, e sim em Concluídas', () {
    final hojeConcluida = session('hoje-ok',
        date: DateTime(2026, 9, 20, 7), status: SessionStatus.concluido);

    expect(idsOf(groupSessions([hojeConcluida], SessionFilter.hoje, agora)),
        isEmpty);
    expect(idsOf(groupSessions([hojeConcluida], SessionFilter.concluidas, agora)),
        ['hoje-ok']);
  });

  test('o contador do chip conta só o grupo principal do filtro', () {
    expect(countFor(todas, SessionFilter.hoje, agora), 1);
    expect(countFor(todas, SessionFilter.proximos7, agora), 2);
    expect(countFor(todas, SessionFilter.concluidas, agora), 1);
  });

  test('sessão cancelada não entra em nenhum filtro de agenda', () {
    final cancelada = session('cancelada',
        date: DateTime(2026, 9, 20, 8), status: SessionStatus.cancelado);

    expect(idsOf(groupSessions([cancelada], SessionFilter.hoje, agora)), isEmpty);
    expect(idsOf(groupSessions([cancelada], SessionFilter.proximos7, agora)),
        isEmpty);
  });
}
