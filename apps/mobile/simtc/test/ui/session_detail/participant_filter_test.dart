import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/session_detail/participant_filter.dart';

void main() {
  const eu = 'c-eu';

  SessionParticipant p(
    String id, {
    String? name,
    ParticipantStatus status = ParticipantStatus.pendente,
    ParticipationType type = ParticipationType.teoricaEPratica,
    String? assignedTo,
    String? assignedName,
    double? score,
    String? assessedBy,
    DateTime? assessedAt,
  }) {
    return SessionParticipant(
      id: id,
      sessionId: 'sess-1',
      name: name ?? 'Participante $id',
      maskedCpf: '042.118.***-**',
      participationType: type,
      status: status,
      assignedConsultantId: assignedTo,
      assignedConsultantName: assignedName,
      score: score,
      assessedByConsultantId: assessedBy,
      assessedAt: assessedAt,
    );
  }

  group('situationOf', () {
    test('somente teórica vence qualquer status', () {
      expect(
        situationOf(
          p('1', type: ParticipationType.somenteTeorica, status: ParticipantStatus.aprovado),
          eu,
        ),
        ParticipantSituation.theoryOnly,
      );
    });

    test('em avaliação é "meu" só quando a atribuição é minha', () {
      final comigo = p('1', status: ParticipantStatus.emAvaliacao, assignedTo: eu);
      final comOutro = p('2', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-2');

      expect(situationOf(comigo, eu), ParticipantSituation.mine);
      expect(situationOf(comOutro, eu), ParticipantSituation.other);
    });

    test('sem perfil de consultor, nada em avaliação é meu', () {
      final semDono = p('1', status: ParticipantStatus.emAvaliacao, assignedTo: null);

      expect(situationOf(semDono, null), ParticipantSituation.other);
    });

    test('aprovado e reavaliar são situações próprias', () {
      expect(situationOf(p('1', status: ParticipantStatus.aprovado), eu),
          ParticipantSituation.approved);
      expect(situationOf(p('2', status: ParticipantStatus.necessitaReavaliacao), eu),
          ParticipantSituation.needsReview);
    });
  });

  group('matchesFilter', () {
    final pendente = p('pend');
    final teorica = p('teo', type: ParticipationType.somenteTeorica);
    final meu = p('meu', status: ParticipantStatus.emAvaliacao, assignedTo: eu);
    final deOutro = p('outro', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-2');
    final avaliadoPorMim = p('ok-meu', status: ParticipantStatus.aprovado, assessedBy: eu);
    final avaliadoPorOutro =
        p('ok-outro', status: ParticipantStatus.necessitaReavaliacao, assessedBy: 'c-2');
    final todos = [pendente, teorica, meu, deOutro, avaliadoPorMim, avaliadoPorOutro];

    List<String> ids(ParticipantFilter filter) => todos
        .where((x) => matchesFilter(x, filter, eu))
        .map((x) => x.id)
        .toList();

    test('Todos traz todo mundo, inclusive quem é só da teórica', () {
      expect(ids(ParticipantFilter.todos), hasLength(6));
    });

    test('Pendentes deixa de fora quem é só da teórica', () {
      expect(ids(ParticipantFilter.pendentes), ['pend']);
    });

    test('Meus junta o que está comigo e o que eu avaliei', () {
      expect(ids(ParticipantFilter.meus), ['meu', 'ok-meu']);
    });

    test('Concluídos junta aprovados e aguardando reavaliação', () {
      expect(ids(ParticipantFilter.concluidos), ['ok-meu', 'ok-outro']);
    });
  });

  test('sortForDisplay segue a ordem do canvas e ignora acentos no nome', () {
    final lista = [
      p('teo', name: 'Simone Barbosa', type: ParticipationType.somenteTeorica),
      p('redo', name: 'Rodrigo Tavares', status: ParticipantStatus.necessitaReavaliacao),
      p('ok', name: 'Juliana Costa', status: ParticipantStatus.aprovado),
      p('outro', name: 'Marcos Alves', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-2'),
      p('pend-z', name: 'Zeca Nunes'),
      p('pend-a', name: 'Ângela Nunes'),
      p('meu', name: 'Ana Ribeiro', status: ParticipantStatus.emAvaliacao, assignedTo: eu),
    ];

    final ordem = sortForDisplay(lista, eu).map((x) => x.id).toList();

    expect(ordem, ['meu', 'pend-a', 'pend-z', 'outro', 'ok', 'redo', 'teo']);
  });

  test('progressOf conta só quem faz a prática', () {
    final progresso = progressOf([
      p('1', status: ParticipantStatus.aprovado),
      p('2', status: ParticipantStatus.necessitaReavaliacao),
      p('3'),
      p('4', status: ParticipantStatus.emAvaliacao, assignedTo: eu),
      p('5', type: ParticipationType.somenteTeorica),
    ]);

    expect(progresso.assessed, 2);
    expect(progresso.assessable, 4);
    expect(progresso.label, '2 de 4 participantes avaliados');
    expect(progresso.percentLabel, '50%');
    expect(progressOf([p('t', type: ParticipationType.somenteTeorica)]).fraction,
        isNull);
  });

  group('rótulos', () {
    test('o chip de quem está com outro usa primeiro e último nome', () {
      final x = p('1',
          status: ParticipantStatus.emAvaliacao,
          assignedTo: 'c-2',
          assignedName: 'Rafael Lima de Souza');

      expect(chipLabelFor(x, ParticipantSituation.other), 'Rafael Souza');
      expect(chipLabelFor(p('2', status: ParticipantStatus.emAvaliacao), ParticipantSituation.other),
          'Outro consultor');
    });

    test('reavaliação em andamento muda o rótulo e a nota', () {
      final minha = p('1', status: ParticipantStatus.emAvaliacao, assignedTo: eu, score: 62);
      final deOutro = p('2', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-2', score: 62);

      expect(chipLabelFor(minha, ParticipantSituation.mine), 'Reavaliando · você');
      expect(blockedNoteFor(deOutro, ParticipantSituation.other),
          'Em reavaliação com outro consultor.');
      expect(chipLabelFor(p('3', status: ParticipantStatus.emAvaliacao, assignedTo: eu),
          ParticipantSituation.mine), 'Avaliando · você');
    });

    test('o score é arredondado como no painel web', () {
      expect(chipLabelFor(p('1', status: ParticipantStatus.aprovado, score: 86.4),
          ParticipantSituation.approved), 'Aprovado · 86%');
      expect(chipLabelFor(p('2', status: ParticipantStatus.necessitaReavaliacao, score: 69.6),
          ParticipantSituation.needsReview), 'Reavaliar · 70%');
    });

    test('só quem está com outro tem nota de bloqueio', () {
      expect(blockedNoteFor(p('1'), ParticipantSituation.pending), isNull);
      expect(blockedNoteFor(p('2', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-2'),
          ParticipantSituation.other), 'Em avaliação com outro consultor.');
    });

    test('o horário da avaliação só aparece nos concluídos', () {
      final agora = DateTime(2026, 9, 23, 14);
      final avaliado = p('1',
          status: ParticipantStatus.aprovado,
          score: 90,
          assessedAt: DateTime(2026, 9, 23, 8, 12));

      expect(assessedAtLabelFor(avaliado, ParticipantSituation.approved, agora),
          'hoje 08:12');
      expect(assessedAtLabelFor(p('2'), ParticipantSituation.pending, agora), isNull);
    });
  });

  group('avaliação deste aparelho', () {
    final agora = DateTime(2026, 9, 29, 9);

    LocalAssessment local(
      LocalSyncStatus status, {
      double? score,
      DateTime? lastAttemptAt,
    }) {
      return LocalAssessment(
        id: 'la-1',
        trainingParticipantId: '1',
        sessionId: 'sess-1',
        date: DateTime(2026, 9, 29),
        startTime: DateTime(2026, 9, 29, 8),
        syncStatus: status,
        attemptCount: 0,
        createdAt: DateTime(2026, 9, 29, 8),
        updatedAt: DateTime(2026, 9, 29, 8),
        score: score,
        lastAttemptAt: lastAttemptAt,
      );
    }

    test('só vale na linha "comigo", e a enviada não muda nada', () {
      const mine = ParticipantSituation.mine;
      expect(localProgressOf(mine, local(LocalSyncStatus.draft)), LocalProgress.draft);
      expect(localProgressOf(mine, local(LocalSyncStatus.pendingSync)),
          LocalProgress.queued);
      expect(localProgressOf(mine, local(LocalSyncStatus.error)), LocalProgress.failed);
      expect(localProgressOf(mine, local(LocalSyncStatus.synced)), isNull);
      expect(localProgressOf(mine, null), isNull);
      expect(
        localProgressOf(ParticipantSituation.approved, local(LocalSyncStatus.pendingSync)),
        isNull,
        reason: 'o servidor já respondeu: vale o status dele',
      );
    });

    test('o meta da fila leva o % e o que está acontecendo', () {
      expect(queueMetaFor(local(LocalSyncStatus.pendingSync, score: 86.6667), agora),
          '86,7% · aguardando envio');
      expect(
        queueMetaFor(
          local(LocalSyncStatus.error, score: 62, lastAttemptAt: DateTime(2026, 9, 29, 7, 58)),
          agora,
        ),
        '62,0% · falhou às 07:58',
      );
      expect(
        queueMetaFor(local(LocalSyncStatus.pendingSync), agora),
        'aguardando envio',
        reason: 'as avaliações da Fase 4 não guardaram o %',
      );
    });
  });
}
