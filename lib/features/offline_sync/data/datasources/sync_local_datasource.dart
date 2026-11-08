import 'dart:convert';
import '../../../../core/storage/database_helper.dart';
import '../../domain/entities/sync_item.dart';

abstract class SyncLocalDataSource {
  Future<void> enqueueItem(SyncItem item);
  Future<List<SyncItem>> getPendingItems();
  Future<SyncItem?> getItemById(String id);
  Future<List<SyncItem>> getAllItems();
  Future<int> getPendingCount();
  Future<void> updateItemStatus(
    String id,
    SyncItemStatus status, {
    int? retryCount,
    String? errorMessage,
  });
  Future<void> deleteItem(String id);
  Future<void> clearCompleted();
}

class SyncLocalDataSourceImpl implements SyncLocalDataSource {
  final DatabaseHelper databaseHelper;

  SyncLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<void> enqueueItem(SyncItem item) async {
    // If mediaFilePaths is present, embed into payload JSON if not already present
    String payload = item.payloadJson;
    if (item.mediaFilePaths.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          decoded['_media_file_paths'] = item.mediaFilePaths;
          payload = jsonEncode(decoded);
        }
      } catch (_) {}
    }

    await databaseHelper.insertSyncQueueItem({
      'id': item.id,
      'endpoint': item.endpoint,
      'method': item.httpMethod,
      'payload': payload,
      'status': item.status.code,
      'retry_count': item.retryCount,
      'created_at': item.createdAt.millisecondsSinceEpoch,
      'idempotency_key': item.idempotencyKey,
    });
  }

  @override
  Future<List<SyncItem>> getPendingItems() async {
    final rows = await databaseHelper.getPendingSyncQueueItems();
    return rows.map(_mapRowToSyncItem).toList();
  }

  @override
  Future<SyncItem?> getItemById(String id) async {
    final row = await databaseHelper.getSyncQueueItemById(id);
    if (row == null) return null;
    return _mapRowToSyncItem(row);
  }

  @override
  Future<List<SyncItem>> getAllItems() async {
    final rows = await databaseHelper.getAllSyncQueueItems();
    return rows.map(_mapRowToSyncItem).toList();
  }

  @override
  Future<int> getPendingCount() async {
    final items = await getPendingItems();
    return items.length;
  }

  @override
  Future<void> updateItemStatus(
    String id,
    SyncItemStatus status, {
    int? retryCount,
    String? errorMessage,
  }) async {
    final statusString = status.code;
    await databaseHelper.updateSyncItemStatus(
      id,
      statusString,
      retryCount: retryCount,
    );
  }

  @override
  Future<void> deleteItem(String id) async {
    await databaseHelper.deleteSyncQueueItem(id);
  }

  @override
  Future<void> clearCompleted() async {
    await databaseHelper.clearCompletedSyncItems();
  }

  SyncItem _mapRowToSyncItem(Map<String, dynamic> row) {
    List<String> mediaPaths = [];
    final payloadString = row['payload'] as String? ?? '{}';

    try {
      final decoded = jsonDecode(payloadString);
      if (decoded is Map<String, dynamic> && decoded['_media_file_paths'] is List) {
        mediaPaths = List<String>.from(decoded['_media_file_paths'] as List);
      }
    } catch (_) {}

    return SyncItem(
      id: row['id'] as String,
      endpoint: row['endpoint'] as String? ?? row['action_type'] as String? ?? '',
      httpMethod: row['method'] as String? ?? 'POST',
      payloadJson: payloadString,
      mediaFilePaths: mediaPaths,
      status: SyncItemStatus.fromString(row['status'] as String? ?? 'QUEUED'),
      retryCount: row['retry_count'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] is int
            ? row['created_at'] as int
            : DateTime.parse(row['created_at'] as String).millisecondsSinceEpoch,
      ),
      idempotencyKey: row['idempotency_key'] as String? ?? row['id'] as String,
    );
  }
}
