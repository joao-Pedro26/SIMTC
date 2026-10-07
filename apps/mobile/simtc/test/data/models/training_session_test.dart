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

  test('date é tratado como data de calendário, não como instante', () {
    // O backend grava a data do formulário web como meia-noite UTC
    // ("2026-09-20T00:00:00.000Z"). Um fuso negativo (ex.: -03:00) faria
    // `.toLocal()` voltar um dia, então aqui a asserção trava os três campos
    // em vez de comparar `DateTime` inteiro — um `toLocal()` reintroduzido
    // pode até bater num fuso UTC+, mas nunca nos três campos abaixo em
    // qualquer fuso negativo, que é o caso real do Brasil.
    final session = TrainingSession.fromJson(
      json(date: '2026-09-20T00:00:00.000Z'),
    );

    expect(session.date, isNotNull);
    expect(session.date!.year, 2026);
    expect(session.date!.month, 9);
    expect(session.date!.day, 20);
  });

  test('lê o consultor responsável da sessão', () {
    final session = TrainingSession.fromJson({
      ...json(),
      'responsibleConsultantId': 'c-resp',
    });

    expect(session.responsibleConsultantId, 'c-resp');
    expect(session.participantsSyncedAt, isNull,
        reason: 'a data de sync dos participantes só existe no cache');
  });

  test('só a sessão planejada ou em andamento aceita mudanças', () {
    expect(SessionStatus.planejado.acceptsChanges, isTrue);
    expect(SessionStatus.emAndamento.acceptsChanges, isTrue);
    expect(SessionStatus.concluido.acceptsChanges, isFalse);
    expect(SessionStatus.cancelado.acceptsChanges, isFalse);
  });
}
