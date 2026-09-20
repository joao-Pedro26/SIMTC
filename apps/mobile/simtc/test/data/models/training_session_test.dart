import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/training_session.dart';

void main() {
  Map<String, dynamic> json({
    String status = 'PLANEJADO',
    String? date = '2026-09-20T12:00:00.000Z',
    Map<String, dynamic>? stats,
  }) {
    return {
      'id': 'sess-1',
      'city': 'Lençóis Paulista',
      'state': 'SP',
      'date': date,
      'notes': null,
      'status': status,
      'company': {'id': 'emp-1', 'name': 'Bracell Celulose'},
      'course': {'id': 'cur-1', 'name': 'Direção Preventiva'},
      'participantStats': stats ?? {'total': 10, 'assessable': 8, 'assessed': 2},
    };
  }

  test('lê os campos aninhados de empresa, curso e contagem', () {
    final session = TrainingSession.fromJson(json());

    expect(session.id, 'sess-1');
    expect(session.companyName, 'Bracell Celulose');
    expect(session.courseName, 'Direção Preventiva');
    expect(session.totalParticipants, 10);
    expect(session.assessableParticipants, 8);
    expect(session.assessedParticipants, 2);
    expect(session.status, SessionStatus.planejado);
  });

  test('aceita sessão sem data e sem contagem', () {
    final semStats = json(date: null)..remove('participantStats');
    final session = TrainingSession.fromJson(semStats);

    expect(session.date, isNull);
    expect(session.totalParticipants, 0);
    expect(session.progress, isNull);
    expect(session.progressLabel, isNull);
  });

  test('status desconhecido não quebra o parsing', () {
    expect(TrainingSession.fromJson(json(status: 'ALGO_NOVO')).status,
        SessionStatus.planejado);
  });

  test('progresso é a fração de avaliáveis concluídos', () {
    final session = TrainingSession.fromJson(json());

    expect(session.progress, 0.25);
    expect(session.progressLabel, '2 de 8 avaliados');
  });

  test('meta junta cidade, UF e total de participantes', () {
    expect(TrainingSession.fromJson(json()).meta,
        'Lençóis Paulista/SP · 10 participantes');
  });

  test('meta no singular quando há um participante só', () {
    final session = TrainingSession.fromJson(
      json(stats: {'total': 1, 'assessable': 1, 'assessed': 0}),
    );

    expect(session.meta, 'Lençóis Paulista/SP · 1 participante');
  });
}
