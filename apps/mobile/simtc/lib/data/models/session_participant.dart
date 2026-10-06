import '../services/local/app_database.dart';

/// Tipo de participação no treinamento. Espelha `ParticipationType` do
/// backend.
enum ParticipationType {
  somenteTeorica,
  teoricaEPratica;

  /// Nome que o backend usa — também é o que vai para o cache.
  String get wireValue => switch (this) {
        ParticipationType.somenteTeorica => 'SOMENTE_TEORICA',
        ParticipationType.teoricaEPratica => 'TEORICA_E_PRATICA',
      };

  /// Um valor desconhecido cai no padrão do backend (`TEORICA_E_PRATICA` é o
  /// `@default` do Prisma) — o mesmo critério de `SessionStatus.parse`.
  static ParticipationType parse(String? value) => value == 'SOMENTE_TEORICA'
      ? ParticipationType.somenteTeorica
      : ParticipationType.teoricaEPratica;
}

/// Situação do participante na avaliação prática. Espelha `ParticipantStatus`
/// do backend.
enum ParticipantStatus {
  pendente,
  emAvaliacao,
  aprovado,
  necessitaReavaliacao;

  String get wireValue => switch (this) {
        ParticipantStatus.pendente => 'PENDENTE',
        ParticipantStatus.emAvaliacao => 'EM_AVALIACAO',
        ParticipantStatus.aprovado => 'APROVADO',
        ParticipantStatus.necessitaReavaliacao => 'NAO_RECOMENDADO',
      };

  /// Um status novo no backend não pode derrubar a lista, então o
  /// desconhecido cai no valor inicial.
  static ParticipantStatus parse(String? value) => switch (value) {
        'EM_AVALIACAO' => ParticipantStatus.emAvaliacao,
        'APROVADO' => ParticipantStatus.aprovado,
        'NAO_RECOMENDADO' => ParticipantStatus.necessitaReavaliacao,
        _ => ParticipantStatus.pendente,
      };
}

/// CPF no formato que o app mostra e guarda: `042.118.***-**`.
///
/// A tela nunca mostra o CPF inteiro (decisão do canvas de design), então o
/// aparelho também não guarda — se o celular for perdido, o cache não entrega
/// o documento de ninguém. Qualquer coisa que não sejam 11 dígitos vira a
/// máscara inteira, em vez de expor um pedaço de um valor malformado.
String maskCpf(String? raw) {
  final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length != 11) return '***.***.***-**';
  return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.***-**';
}

/// Um participante inscrito numa sessão (`TrainingParticipant`), achatado com
/// o cadastro (`Participant`) e a avaliação já sincronizada, quando houver.
class SessionParticipant {
  const SessionParticipant({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.maskedCpf,
    required this.participationType,
    required this.status,
    this.assignedConsultantId,
    this.assignedConsultantName,
    this.score,
    this.assessedByConsultantId,
    this.assessedAt,
  });

  /// Id do `TrainingParticipant` — é o que `assign` e `sync` recebem.
  final String id;
  final String sessionId;
  final String name;

  /// Já mascarado — ver [maskCpf].
  final String maskedCpf;
  final ParticipationType participationType;
  final ParticipantStatus status;

  /// Quem está com o participante agora (só faz sentido em `EM_AVALIACAO`).
  final String? assignedConsultantId;
  final String? assignedConsultantName;

  /// Score da última avaliação sincronizada, de 0 a 100.
  final double? score;

  /// Quem fez a última avaliação sincronizada — entra no filtro "Meus".
  final String? assessedByConsultantId;

  /// Fim (ou início, se não houver fim) da última avaliação sincronizada.
  final DateTime? assessedAt;

  /// Já tem resultado: aprovado ou aguardando reavaliação.
  bool get isAssessed =>
      status == ParticipantStatus.aprovado ||
      status == ParticipantStatus.necessitaReavaliacao;

  /// Existe uma avaliação anterior. Com o participante de novo em
  /// `EM_AVALIACAO`, é uma reavaliação em andamento — mesmo critério do web
  /// (`getDisplayStatus`, `participants-tab.tsx`).
  bool get hasPreviousAssessment => score != null;

  /// Monta a partir de um item de `participants[]` de
  /// `GET /training-sessions/:id`.
  factory SessionParticipant.fromJson(
    Map<String, dynamic> json, {
    required String sessionId,
  }) {
    final participant = json['participant'] as Map<String, dynamic>? ?? const {};
    final assessment = json['assessment'] as Map<String, dynamic>?;
    final assigned = json['assignedConsultant'] as Map<String, dynamic>?;
    final end = assessment?['endTime'] as String?;
    final start = assessment?['startTime'] as String?;

    return SessionParticipant(
      id: json['id'] as String? ?? '',
      sessionId: sessionId,
      name: participant['name'] as String? ?? '',
      maskedCpf: maskCpf(participant['cpf'] as String?),
      participationType:
          ParticipationType.parse(json['participationType'] as String?),
      status: ParticipantStatus.parse(json['status'] as String?),
      assignedConsultantId:
          json['assignedConsultantId'] as String? ?? assigned?['id'] as String?,
      assignedConsultantName: assigned?['name'] as String?,
      score: (assessment?['score'] as num?)?.toDouble(),
      assessedByConsultantId: assessment?['consultantId'] as String?,
      // `endTime`/`startTime` são instantes de verdade (não datas de
      // calendário como `TrainingSession.date`): a hora local é a certa.
      assessedAt: DateTime.tryParse(end ?? start ?? ''),
    );
  }

  /// Reconstrói a partir da linha do cache local.
  factory SessionParticipant.fromRow(Participant row) {
    return SessionParticipant(
      id: row.id,
      sessionId: row.sessionId,
      name: row.name,
      maskedCpf: row.cpf,
      participationType: ParticipationType.parse(row.participationType),
      status: ParticipantStatus.parse(row.status),
      assignedConsultantId: row.assignedConsultantId,
      assignedConsultantName: row.assignedConsultantName,
      score: row.score,
      assessedByConsultantId: row.assessedByConsultantId,
      assessedAt: row.assessedAt,
    );
  }
}
