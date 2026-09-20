import '../services/local/app_database.dart';

/// Situação de uma sessão de treinamento. Espelha `TrainingStatus` do backend —
/// o valor inicial lá é `PLANEJADO`, não `AGENDADO`.
enum SessionStatus {
  planejado('Planejado'),
  emAndamento('Em andamento'),
  concluido('Concluído'),
  cancelado('Cancelado');

  const SessionStatus(this.label);

  final String label;

  /// Nome que o backend usa — também é o que vai para o cache.
  String get wireValue => switch (this) {
        SessionStatus.planejado => 'PLANEJADO',
        SessionStatus.emAndamento => 'EM_ANDAMENTO',
        SessionStatus.concluido => 'CONCLUIDO',
        SessionStatus.cancelado => 'CANCELADO',
      };

  /// Um status novo no backend não pode derrubar a lista inteira do consultor
  /// em campo, então o desconhecido cai no valor inicial.
  static SessionStatus parse(String? value) => switch (value) {
        'EM_ANDAMENTO' => SessionStatus.emAndamento,
        'CONCLUIDO' => SessionStatus.concluido,
        'CANCELADO' => SessionStatus.cancelado,
        _ => SessionStatus.planejado,
      };
}

/// Uma sessão de treinamento como o app a usa — já achatada, sem os objetos
/// aninhados do backend.
class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.companyName,
    required this.courseName,
    required this.city,
    required this.state,
    required this.status,
    required this.totalParticipants,
    required this.assessableParticipants,
    required this.assessedParticipants,
    this.companyLogoUrl,
    this.date,
    this.notes,
  });

  final String id;
  final String companyName;
  final String? companyLogoUrl;
  final String courseName;
  final String city;
  final String state;
  final DateTime? date;
  final SessionStatus status;
  final String? notes;

  /// Todos os inscritos. Vem de `participantStats.total`, não do campo
  /// `participantCount` do cadastro, que é só uma previsão e envelhece.
  final int totalParticipants;

  /// Denominador do progresso: só quem faz a prática.
  final int assessableParticipants;

  /// Numerador do progresso: avaliáveis já concluídos.
  final int assessedParticipants;

  static int _asInt(Object? value) => value is num ? value.toInt() : 0;

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    final company = json['company'] as Map<String, dynamic>? ?? const {};
    final course = json['course'] as Map<String, dynamic>? ?? const {};
    final stats = json['participantStats'] as Map<String, dynamic>? ?? const {};
    final date = json['date'] as String?;

    return TrainingSession(
      id: json['id'] as String? ?? '',
      companyName: company['name'] as String? ?? '',
      companyLogoUrl: company['logoUrl'] as String?,
      courseName: course['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      date: date == null ? null : DateTime.tryParse(date)?.toLocal(),
      status: SessionStatus.parse(json['status'] as String?),
      notes: json['notes'] as String?,
      totalParticipants: _asInt(stats['total']),
      assessableParticipants: _asInt(stats['assessable']),
      assessedParticipants: _asInt(stats['assessed']),
    );
  }

  /// Reconstrói a partir da linha do cache local.
  factory TrainingSession.fromRow(Session row) {
    return TrainingSession(
      id: row.id,
      companyName: row.companyName,
      companyLogoUrl: row.companyLogoUrl,
      courseName: row.courseName,
      city: row.city,
      state: row.state,
      date: row.date,
      status: SessionStatus.parse(row.status),
      notes: row.notes,
      totalParticipants: row.totalParticipants,
      assessableParticipants: row.assessableParticipants,
      assessedParticipants: row.assessedParticipants,
    );
  }

  /// Fração de 0 a 1 para a barra do card; nula quando ninguém é avaliável
  /// (aí o card não mostra barra nenhuma, em vez de uma barra vazia mentirosa).
  double? get progress {
    if (assessableParticipants <= 0) return null;
    return assessedParticipants / assessableParticipants;
  }

  String? get progressLabel {
    if (assessableParticipants <= 0) return null;
    return '$assessedParticipants de $assessableParticipants avaliados';
  }

  /// Linha de metadados do card: onde é e quanta gente tem.
  String get meta {
    final plural = totalParticipants == 1 ? 'participante' : 'participantes';
    return '$city/$state · $totalParticipants $plural';
  }
}
