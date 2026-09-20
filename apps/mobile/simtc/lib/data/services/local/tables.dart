import 'package:drift/drift.dart';

/// Situação de sincronização de uma avaliação feita no aparelho.
enum LocalSyncStatus {
  /// Em preenchimento; ainda não finalizada pelo consultor.
  draft,

  /// Finalizada e aguardando envio.
  pendingSync,

  /// Aceita pelo backend.
  synced,

  /// O envio falhou; fica na fila para nova tentativa.
  error,
}

/// Cache das sessões de `GET /training-sessions`.
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get companyName => text()();
  TextColumn get companyLogoUrl => text().nullable()();
  TextColumn get courseName => text()();
  TextColumn get city => text()();
  TextColumn get state => text()();
  DateTimeColumn get date => dateTime().nullable()();
  TextColumn get status => text()();
  TextColumn get notes => text().nullable()();

  /// Quando esta linha veio da API — mostra ao usuário a idade do cache.
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cache dos participantes de uma sessão (`TrainingParticipant`).
class Participants extends Table {
  /// Id do `TrainingParticipant` (não o do `Participant`).
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id)();
  TextColumn get name => text()();
  TextColumn get cpf => text()();
  TextColumn get email => text().nullable()();
  TextColumn get participationType => text()();
  TextColumn get status => text()();
  TextColumn get assignedConsultantId => text().nullable()();
  TextColumn get assignedConsultantName => text().nullable()();

  /// Score da avaliação já sincronizada, quando houver.
  RealColumn get score => real().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Catálogo: categorias de avaliação (`GET /assessment-categories`).
class AssessmentCategories extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get order => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Catálogo: infrações de cada categoria.
class Infractions extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(AssessmentCategories, #id)();
  TextColumn get description => text()();
  IntColumn get order => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Catálogo: notas de cada infração (B, PM, M) com o peso usado no score.
class InfractionNotes extends Table {
  TextColumn get id => text()();
  TextColumn get infractionId => text().references(Infractions, #id)();

  /// `B`, `PM` ou `M`, como vem do backend.
  TextColumn get noteType => text()();
  TextColumn get comment => text().nullable()();

  /// `deduction` do backend — o cálculo do score usa este valor, não constantes.
  IntColumn get deduction => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Avaliação preenchida no aparelho (rascunho, fila de envio e histórico).
class LocalAssessments extends Table {
  /// Id local (uuid), gerado no aparelho — o id do backend só existe após o sync.
  TextColumn get id => text()();

  /// `TrainingParticipant.id`; um participante tem no máximo uma avaliação.
  TextColumn get trainingParticipantId => text()();
  TextColumn get sessionId => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get syncStatus => textEnum<LocalSyncStatus>()();

  /// Mensagem do último erro de envio, mostrada na tela de Sincronização.
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {trainingParticipantId},
      ];
}

/// Nota marcada em uma infração dentro de uma avaliação local.
class LocalAssessmentItems extends Table {
  TextColumn get id => text()();
  TextColumn get localAssessmentId => text().references(LocalAssessments, #id)();
  TextColumn get infractionId => text()();

  /// `InfractionNote.id` escolhido — é o que o sync envia.
  TextColumn get infractionNoteId => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  /// Uma nota por infração em cada avaliação: remarcar substitui a anterior.
  @override
  List<Set<Column>> get uniqueKeys => [
        {localAssessmentId, infractionId},
      ];
}
