import '../../data/models/session_participant.dart';
import '../../data/services/local/app_database.dart';
import '../core/date_labels.dart';
import '../core/score_labels.dart';

/// Os quatro chips da tela 1.4. Aqui eles filtram de verdade (o canvas tem
/// "Todos"), ao contrário dos chips da Home, que são âncoras de rolagem.
enum ParticipantFilter {
  todos('Todos'),
  pendentes('Pendentes'),
  meus('Meus'),
  concluidos('Concluídos');

  const ParticipantFilter(this.label);

  final String label;
}

/// O que uma linha da lista é, do ponto de vista do consultor logado. A ordem
/// do enum é a ordem da lista no canvas: o trabalho dele primeiro, o que dá
/// para pegar em seguida, o que está com outro, os concluídos e, por último,
/// quem nem passa pela prática.
enum ParticipantSituation { mine, pending, other, approved, needsReview, theoryOnly }

ParticipantSituation situationOf(
  SessionParticipant participant,
  String? myConsultantId,
) {
  if (participant.participationType == ParticipationType.somenteTeorica) {
    return ParticipantSituation.theoryOnly;
  }
  return switch (participant.status) {
    ParticipantStatus.pendente => ParticipantSituation.pending,
    ParticipantStatus.emAvaliacao => myConsultantId != null &&
            participant.assignedConsultantId == myConsultantId
        ? ParticipantSituation.mine
        : ParticipantSituation.other,
    ParticipantStatus.aprovado => ParticipantSituation.approved,
    ParticipantStatus.necessitaReavaliacao => ParticipantSituation.needsReview,
  };
}

bool _isConcluded(ParticipantSituation situation) =>
    situation == ParticipantSituation.approved ||
    situation == ParticipantSituation.needsReview;

/// Regra dos chips (decidida com o usuário em 23/09/2026):
/// - **Pendentes**: ninguém pegou ainda (quem é só da teórica não entra);
/// - **Meus**: em avaliação comigo **e** os que eu mesmo avaliei;
/// - **Concluídos**: aprovados e aguardando reavaliação.
bool matchesFilter(
  SessionParticipant participant,
  ParticipantFilter filter,
  String? myConsultantId,
) {
  final situation = situationOf(participant, myConsultantId);
  return switch (filter) {
    ParticipantFilter.todos => true,
    ParticipantFilter.pendentes => situation == ParticipantSituation.pending,
    ParticipantFilter.meus => situation == ParticipantSituation.mine ||
        (_isConcluded(situation) &&
            myConsultantId != null &&
            participant.assessedByConsultantId == myConsultantId),
    ParticipantFilter.concluidos => _isConcluded(situation),
  };
}

/// Posição do grupo na lista — aprovados e reavaliar dividem o mesmo grupo
/// ("concluídos"), em ordem de nome entre si, como no canvas.
int _groupOf(ParticipantSituation situation) => switch (situation) {
      ParticipantSituation.mine => 0,
      ParticipantSituation.pending => 1,
      ParticipantSituation.other => 2,
      ParticipantSituation.approved || ParticipantSituation.needsReview => 3,
      ParticipantSituation.theoryOnly => 4,
    };

const Map<String, String> _semAcento = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c',
};

/// Chave de ordenação por nome que põe "Ângela" junto de "Ana", e não depois
/// de "Zeca" — o SQLite só ignora caixa em letras sem acento.
String _nameKey(String name) {
  final lower = name.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_semAcento[char] ?? char);
  }
  return buffer.toString();
}

/// A lista na ordem do canvas: por grupo e, dentro do grupo, por nome.
/// Comparador completo (e não um `sort` estável sobre a ordem do banco),
/// porque o `List.sort` do Dart não garante estabilidade.
List<SessionParticipant> sortForDisplay(
  List<SessionParticipant> participants,
  String? myConsultantId,
) {
  final sorted = [...participants];
  sorted.sort((a, b) {
    final byGroup = _groupOf(situationOf(a, myConsultantId))
        .compareTo(_groupOf(situationOf(b, myConsultantId)));
    if (byGroup != 0) return byGroup;
    return _nameKey(a.name).compareTo(_nameKey(b.name));
  });
  return sorted;
}

/// "X de Y participantes avaliados" do cabeçalho — a mesma regra do
/// `participantStats` do backend: só quem faz a prática entra na conta.
class ParticipantProgress {
  const ParticipantProgress({required this.assessed, required this.assessable});

  final int assessed;
  final int assessable;

  /// De 0 a 1; nulo quando ninguém faz a prática (aí não há barra).
  double? get fraction => assessable <= 0 ? null : assessed / assessable;

  String get label => '$assessed de $assessable participantes avaliados';

  String get percentLabel => '${((fraction ?? 0) * 100).round()}%';
}

ParticipantProgress progressOf(List<SessionParticipant> participants) {
  final assessable = participants
      .where((p) => p.participationType == ParticipationType.teoricaEPratica)
      .toList(growable: false);
  return ParticipantProgress(
    assessed: assessable.where((p) => p.isAssessed).length,
    assessable: assessable.length,
  );
}

/// "Rafael Lima" de "Rafael Lima de Souza": o chip é estreito, e o primeiro e
/// o último nome bastam para o consultor saber com quem falar.
String _shortName(String fullName) {
  final words =
      fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length <= 2) return words.join(' ');
  return '${words.first} ${words.last}';
}

/// Score arredondado como no painel web (`Math.round`), para os números
/// baterem — inclusive o 69,6 que aparece "70%" ao lado de "Reavaliar".
String _percent(double? score) => score == null ? '' : ' · ${score.round()}%';

String chipLabelFor(
  SessionParticipant participant,
  ParticipantSituation situation,
) {
  return switch (situation) {
    ParticipantSituation.theoryOnly => 'Somente teórica',
    ParticipantSituation.pending => 'Pendente',
    ParticipantSituation.mine => participant.hasPreviousAssessment
        ? 'Reavaliando · você'
        : 'Avaliando · você',
    ParticipantSituation.other =>
      _shortName(participant.assignedConsultantName ?? '').isEmpty
          ? 'Outro consultor'
          : _shortName(participant.assignedConsultantName!),
    ParticipantSituation.approved => 'Aprovado${_percent(participant.score)}',
    ParticipantSituation.needsReview =>
      'Reavaliar${_percent(participant.score)}',
  };
}

/// Explica por que a linha não tem ação. Só existe para quem está com outro
/// consultor — o canvas tinha "desde 08:29", mas o backend não guarda quando
/// a atribuição aconteceu.
String? blockedNoteFor(
  SessionParticipant participant,
  ParticipantSituation situation,
) {
  if (situation != ParticipantSituation.other) return null;
  return participant.hasPreviousAssessment
      ? 'Em reavaliação com outro consultor.'
      : 'Em avaliação com outro consultor.';
}

/// "hoje 08:12" dos concluídos. Nulo para quem ainda não tem avaliação.
String? assessedAtLabelFor(
  SessionParticipant participant,
  ParticipantSituation situation,
  DateTime now,
) {
  if (!_isConcluded(situation) || participant.assessedAt == null) return null;
  return momentLabel(participant.assessedAt!, now);
}

/// Onde está a avaliação deste aparelho numa linha "comigo" (Fase 5A).
enum LocalProgress {
  /// Rascunho aberto: a linha mostra o cronômetro.
  draft,

  /// Confirmada, esperando o envio: chip "Na fila".
  queued,

  /// O último envio falhou: chip "Erro no envio".
  failed,

  /// Enviada e aceita, mas a sessão ainda não foi baixada de novo: chip
  /// "Enviada". Depois do download, vale o status do servidor.
  sent,
}

/// Só vale para a linha "comigo" — depois do envio, quem manda é o status
/// que o servidor devolve (Aprovado/Reavaliar). Entre o envio aceito e o
/// próximo download dos participantes, porém, o cache do servidor ainda
/// mostra o participante comigo (revisão de 30/09/2026): [participantsSyncedAt]
/// decide se esse download já aconteceu depois do envio (`sent` some, vale o
/// servidor) ou não (`sent` continua).
LocalProgress? localProgressOf(
  ParticipantSituation situation,
  LocalAssessment? local,
  DateTime? participantsSyncedAt,
) {
  if (situation != ParticipantSituation.mine || local == null) return null;
  return switch (local.syncStatus) {
    LocalSyncStatus.draft => LocalProgress.draft,
    LocalSyncStatus.pendingSync => LocalProgress.queued,
    LocalSyncStatus.error => LocalProgress.failed,
    LocalSyncStatus.synced => _sentOrNull(local, participantsSyncedAt),
  };
}

/// `sent` enquanto a sessão não foi baixada de novo depois do último envio;
/// nula assim que o download passa a ser posterior a ele — aí quem manda é o
/// status do servidor. Sem `lastAttemptAt` (não acontece: `saveSendResults`
/// sempre grava) não dá para comparar, e a linha segue o servidor.
LocalProgress? _sentOrNull(LocalAssessment local, DateTime? participantsSyncedAt) {
  final lastAttempt = local.lastAttemptAt;
  if (lastAttempt == null) return null;
  final aindaNaoBaixou =
      participantsSyncedAt == null || participantsSyncedAt.isBefore(lastAttempt);
  return aindaNaoBaixou ? LocalProgress.sent : null;
}

/// "86,7% · aguardando envio", "62,0% · falhou às 07:58" ou "86,7% · enviada
/// às 08:12", da linha na fila. As avaliações de antes da Fase 5A não
/// guardaram o %: vai só o texto.
String queueMetaFor(LocalAssessment local, DateTime now) {
  final lastAttempt = local.lastAttemptAt;
  final status = switch (local.syncStatus) {
    LocalSyncStatus.error when lastAttempt != null =>
      'falhou ${atLabel(lastAttempt, now)}',
    LocalSyncStatus.synced when lastAttempt != null =>
      'enviada ${atLabel(lastAttempt, now)}',
    _ => 'aguardando envio',
  };
  final score = local.score;
  return score == null ? status : '${percentLabel(score)} · $status';
}
