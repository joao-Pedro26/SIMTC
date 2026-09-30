import 'package:flutter/foundation.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';

class _UnusedApiClient extends Mock implements ApiClient {}

class _UnusedAssessmentRepository extends Mock implements AssessmentRepository {}

class _UnusedParticipantRepository extends Mock implements ParticipantRepository {}

/// `AssessmentSyncService` para testes de tela: o teste define a fila, o
/// envio no ar e a última sincronização, e nada é enviado de verdade. Nunca é
/// iniciado (`start`), então não segue usuário, fila nem conexão.
class FakeAssessmentSyncService extends AssessmentSyncService {
  FakeAssessmentSyncService({
    List<LocalAssessment> queue = const [],
    Set<String> sendingIds = const {},
    DateTime? lastSyncedAt,
  })  : _queue = queue,
        _sendingIds = sendingIds,
        _lastSyncedAt = lastSyncedAt,
        super(
          apiClient: _UnusedApiClient(),
          assessments: _UnusedAssessmentRepository(),
          participants: _UnusedParticipantRepository(),
          connectivity: ConnectivityService(),
          authChanges: ValueNotifier<String?>(null),
          currentUserId: () => null,
        );

  List<LocalAssessment> _queue;
  Set<String> _sendingIds;
  final DateTime? _lastSyncedAt;

  /// Quantas vezes a tela pediu para enviar agora.
  int syncNowCalls = 0;

  @override
  List<LocalAssessment> get queue => _queue;

  @override
  bool get isSending => _sendingIds.isNotEmpty;

  @override
  bool isSendingItem(String localAssessmentId) =>
      _sendingIds.contains(localAssessmentId);

  @override
  DateTime? get lastSyncedAt => _lastSyncedAt;

  @override
  Future<void> syncNow() async => syncNowCalls++;

  /// Troca a fila e avisa a tela, como o stream do banco faria.
  void setQueue(List<LocalAssessment> queue, {Set<String> sendingIds = const {}}) {
    _queue = queue;
    _sendingIds = sendingIds;
    notifyListeners();
  }
}

/// Uma avaliação da fila, do jeito que o `AssessmentRepository` guarda.
LocalAssessment queuedAssessment(
  String participantId, {
  LocalSyncStatus status = LocalSyncStatus.pendingSync,
  String? participantName,
  double? score,
  DateTime? endTime,
  DateTime? lastAttemptAt,
  String? lastError,
}) {
  final at = endTime ?? DateTime.now();
  return LocalAssessment(
    id: 'local-$participantId',
    trainingParticipantId: participantId,
    sessionId: 'sess-1',
    date: at,
    startTime: at.subtract(const Duration(minutes: 14)),
    endTime: at,
    syncStatus: status,
    attemptCount: 0,
    createdAt: at,
    updatedAt: at,
    ownerUserId: 'u1',
    participantName: participantName,
    score: score,
    lastAttemptAt: lastAttemptAt,
    lastError: lastError,
  );
}
