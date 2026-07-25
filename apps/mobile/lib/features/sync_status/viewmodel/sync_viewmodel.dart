import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/sync_status.dart';
import '../../../core/network/connectivity.dart';
import '../../../core/sync/sync_service.dart';

part 'sync_viewmodel.g.dart';

@riverpod
class SyncViewModel extends _$SyncViewModel {
  @override
  SyncStatusType build() {
    // Observa conectividade e dispara sync
    ref.listen(isOnlineProvider, (previous, next) async {
      if (next.value == true) {
        state = SyncStatusType.syncing;
        try {
          await ref.read(syncServiceProvider.notifier).syncPending();
          state = SyncStatusType.online;
        } catch (_) {
          state = SyncStatusType.error;
        }
      } else {
        state = SyncStatusType.offline;
      }
    });
    return SyncStatusType.online;
  }
}
