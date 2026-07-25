import 'package:drift/drift.dart';

/// Espelha as tabelas do servidor para a sessão ativa (uso offline)

class LocalTrainingSessions extends Table {
  TextColumn get id           => text()();
  TextColumn get companyName  => text()();
  TextColumn get courseName   => text()();
  TextColumn get city         => text()();
  TextColumn get state        => text()();
  TextColumn get status       => text()();
  TextColumn get qrCodeToken  => text()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalParticipants extends Table {
  TextColumn get id                   => text()();
  TextColumn get trainingParticipantId => text()();
  TextColumn get trainingSessionId     => text()();
  TextColumn get name                  => text()();
  TextColumn get cpf                   => text()();
  TextColumn get email                 => text().nullable()();
  TextColumn get status                => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalAssessmentCategories extends Table {
  TextColumn get id    => text()();
  TextColumn get code  => text()();
  TextColumn get name  => text()();
  IntColumn  get order => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalInfractions extends Table {
  TextColumn get id          => text()();
  TextColumn get categoryId  => text()();
  TextColumn get description => text()();
  IntColumn  get order       => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalInfractionNotes extends Table {
  TextColumn get id           => text()();
  TextColumn get infractionId => text()();
  TextColumn get noteType     => text()(); // B, PM, M
  IntColumn  get deduction    => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalPracticalAssessments extends Table {
  TextColumn  get id                    => text()();
  TextColumn  get trainingParticipantId => text()();
  TextColumn  get consultantId          => text()();
  DateTimeColumn get date               => dateTime()();
  DateTimeColumn get startTime          => dateTime()();
  DateTimeColumn get endTime            => dateTime().nullable()();
  BoolColumn  get synced                => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalAssessmentItems extends Table {
  TextColumn get id               => text()();
  TextColumn get assessmentId     => text()();
  TextColumn get infractionNoteId => text()();

  @override
  Set<Column> get primaryKey => {id};
}
