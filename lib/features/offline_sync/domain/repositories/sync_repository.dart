import '../entities/sync_item.dart';

abstract class SyncRepository {
  Future<void> enqueueRequest(SyncItem item);
  Future<List<SyncItem>> getPendingQueue();
  Future<void> processSyncQueue();
  Stream<int> watchPendingCount();

  // Backward-compatibility aliases
  Future<void> enqueueSyncItem(SyncItem item) => enqueueRequest(item);
  Future<List<SyncItem>> getPendingItems() => getPendingQueue();
  Future<int> getPendingCount() async => (await getPendingQueue()).length;
  Future<void> syncAllPending() => processSyncQueue();
}
