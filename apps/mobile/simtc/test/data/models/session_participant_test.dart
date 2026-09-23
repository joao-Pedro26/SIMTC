import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/services/local/app_database.dart';

void main() {
  /// Um item de `participants[]` como `GET /training-sessions/:id` devolve
  /// (include de `participant`, `assessment`, `certificate` e
  /// `assignedConsultant`, conferido em `training-sessions.service.ts`).
  Map<String, dynamic> json({
    String status = 'PENDENTE',
    String participationType = 'TEORICA_E_PRATICA',
    String cpf = '04211899001',
    Map<String, dynamic>? assessment,
    Map<String, dynamic>? assignedConsultant,
  }) {
    return {
      'id': 'tp-1',
      'trainingSessionId': 'sess-1',
      'participantId': 'p-1',
      'participationType': participationType,
      'status': status,
      'assignedConsultantId': assignedConsultant?['id'],
      'registeredAt': '2026-09-20T10:00:00.000Z',
      'participant': {
        'id': 'p-1',
        'name': 'Ana Paula Ribeiro',
        'cpf': cpf,
        'email': 'ana@exemplo.com',
      },
      'assessment': assessment,
      'certificate': null,
      'assignedConsultant': assignedConsultant,
    };
  }

  test('lê o cadastro e guarda o CPF já mascarado', () {
    final p = SessionParticipant.fromJson(json(), sessionId: 'sess-1');

    expect(p.id, 'tp-1');
    expect(p.sessionId, 'sess-1');
    expect(p.name, 'Ana Paula Ribeiro');
    expect(p.maskedCpf, '042.118.***-**');
    expect(p.participationType, ParticipationType.teoricaEPratica);
    expect(p.status, ParticipantStatus.pendente);
    expect(p.score, isNull);
    expect(p.isAssessed, isFalse);
  });

  test('lê quem está com o participante em avaliação', () {
    final p = SessionParticipant.fromJson(
      json(
        status: 'EM_AVALIACAO',
        assignedConsultant: {'id': 'c-2', 'name': 'Rafael Lima'},
      ),
      sessionId: 'sess-1',
    );

    expect(p.status, ParticipantStatus.emAvaliacao);
    expect(p.assignedConsultantId, 'c-2');
    expect(p.assignedConsultantName, 'Rafael Lima');
  });

  test('lê score, avaliador e momento da avaliação sincronizada', () {
    final p = SessionParticipant.fromJson(
      json(
        status: 'APROVADO',
        assessment: {
          'id': 'pa-1',
          'consultantId': 'c-1',
          'date': '2026-09-23T00:00:00.000Z',
          'startTime': '2026-09-23T10:58:00.000Z',
          'endTime': '2026-09-23T11:12:00.000Z',
          'score': 86.4,
        },
      ),
      sessionId: 'sess-1',
    );

    expect(p.score, 86.4);
    expect(p.assessedByConsultantId, 'c-1');
    expect(p.assessedAt, DateTime.parse('2026-09-23T11:12:00.000Z'));
    expect(p.isAssessed, isTrue);
    expect(p.hasPreviousAssessment, isTrue);
  });

  test('sem endTime, o momento da avaliação é o startTime', () {
    final p = SessionParticipant.fromJson(
      json(
        status: 'NECESSITA_REAVALIACAO',
        assessment: {
          'consultantId': 'c-1',
          'startTime': '2026-09-23T10:58:00.000Z',
          'endTime': null,
          'score': 62,
        },
      ),
      sessionId: 'sess-1',
    );

    expect(p.assessedAt, DateTime.parse('2026-09-23T10:58:00.000Z'));
    expect(p.score, 62.0);
  });

  test('status e tipo desconhecidos caem nos valores iniciais do backend', () {
    final p = SessionParticipant.fromJson(
      json(status: 'ALGO_NOVO', participationType: 'OUTRO_TIPO'),
      sessionId: 'sess-1',
    );

    expect(p.status, ParticipantStatus.pendente);
    expect(p.participationType, ParticipationType.teoricaEPratica);
  });

  test('lê o tipo somente teórica', () {
    final p = SessionParticipant.fromJson(
      json(participationType: 'SOMENTE_TEORICA'),
      sessionId: 'sess-1',
    );

    expect(p.participationType, ParticipationType.somenteTeorica);
  });

  group('maskCpf', () {
    test('mantém só os 6 primeiros dígitos, com pontuação ou sem', () {
      expect(maskCpf('04211899001'), '042.118.***-**');
      expect(maskCpf('042.118.990-01'), '042.118.***-**');
    });

    test('CPF malformado ou ausente vira a máscara inteira', () {
      expect(maskCpf('123'), '***.***.***-**');
      expect(maskCpf(''), '***.***.***-**');
      expect(maskCpf(null), '***.***.***-**');
    });
  });

  test('fromRow devolve o mesmo participante que foi para o cache', () {
    final row = Participant(
      id: 'tp-1',
      sessionId: 'sess-1',
      name: 'Ana Paula Ribeiro',
      cpf: '042.118.***-**',
      participationType: 'SOMENTE_TEORICA',
      status: 'EM_AVALIACAO',
      assignedConsultantId: 'c-1',
      assignedConsultantName: 'Carla Souza',
      score: 70,
      assessedByConsultantId: 'c-3',
      assessedAt: DateTime(2026, 9, 23, 8, 12),
      cachedAt: DateTime(2026, 9, 23, 9),
    );

    final p = SessionParticipant.fromRow(row);

    expect(p.maskedCpf, '042.118.***-**');
    expect(p.participationType, ParticipationType.somenteTeorica);
    expect(p.status, ParticipantStatus.emAvaliacao);
    expect(p.assignedConsultantName, 'Carla Souza');
    expect(p.score, 70);
    expect(p.assessedByConsultantId, 'c-3');
    expect(p.assessedAt, DateTime(2026, 9, 23, 8, 12));
    expect(p.hasPreviousAssessment, isTrue);
  });
}
