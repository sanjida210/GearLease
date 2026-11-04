import '../entities/sync_item.dart';

abstract class SyncRepository {
  Future<void> enqueueSyncItem(SyncItem item);
  Future<List<SyncItem>> getPendingItems();
  Future<int> getPendingCount();
  Stream<int> watchPendingCount();
  Future<void> syncAllPending();
}
