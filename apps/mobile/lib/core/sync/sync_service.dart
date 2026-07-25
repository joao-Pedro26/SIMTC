import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../network/connectivity.dart';
import '../network/api_client.dart';

part 'sync_service.g.dart';

/// Orquestra a sincronização das avaliações offline → servidor
/// É disparado automaticamente quando a conectividade é restaurada.
@riverpod
class SyncService extends _$SyncService {
  @override
  Future<void> build() async {
    // Observa conexão e dispara sync ao reconectar
    ref.listen(isOnlineProvider, (previous, next) {
      if (next.value == true && previous?.value != true) {
        syncPending();
      }
    });
  }

  /// Busca avaliações com synced=false no banco local e envia em lote
  Future<void> syncPending() async {
    // TODO: implementar com Drift DAO
    // 1. Buscar PracticalAssessments onde synced = false
    // 2. Fazer POST /practical-assessments/sync
    // 3. Marcar como synced = true
  }
}
