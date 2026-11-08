import '../../../../core/storage/database_helper.dart';
import '../../domain/entities/sync_item.dart';

abstract class SyncLocalDataSource {
  Future<void> enqueueItem(SyncItem item);
  Future<List<SyncItem>> getPendingItems();
  Future<int> getPendingCount();
  Future<void> updateItemStatus(String id, SyncStatus status, {String? errorMessage});
}

class SyncLocalDataSourceImpl implements SyncLocalDataSource {
  final DatabaseHelper databaseHelper;

  SyncLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<void> enqueueItem(SyncItem item) async {
    await databaseHelper.insertSyncQueueItem({
      'id': item.id,
      'endpoint': item.actionType,
      'method': 'POST',
      'payload': item.payloadJson,
      'status': 'PENDING',
      'retry_count': 0,
      'created_at': item.createdAt.millisecondsSinceEpoch,
      'idempotency_key': item.idempotencyKey,
    });
  }

  @override
  Future<List<SyncItem>> getPendingItems() async {
    final rows = await databaseHelper.getPendingSyncQueueItems();
    return rows.map((row) {
      return SyncItem(
        id: row['id'] as String,
        idempotencyKey: row['idempotency_key'] as String? ?? row['id'] as String,
        actionType: row['endpoint'] as String,
        payloadJson: row['payload'] as String,
        status: _parseStatus(row['status'] as String?),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      );
    }).toList();
  }

  @override
  Future<int> getPendingCount() async {
    final items = await getPendingItems();
    return items.length;
  }

  @override
  Future<void> updateItemStatus(
    String id,
    SyncStatus status, {
    String? errorMessage,
  }) async {
    final statusString = status.name.toUpperCase();
    await databaseHelper.updateSyncItemStatus(id, statusString);
  }

  SyncStatus _parseStatus(String? status) {
    if (status == null) return SyncStatus.pending;
    switch (status.toUpperCase()) {
      case 'SYNCING':
        return SyncStatus.syncing;
      case 'SYNCED':
      case 'COMPLETED':
        return SyncStatus.synced;
      case 'FAILED':
        return SyncStatus.failed;
      case 'PENDING':
      default:
        return SyncStatus.pending;
    }
  }
}
