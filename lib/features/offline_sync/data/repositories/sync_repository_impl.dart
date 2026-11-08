import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/sync_item.dart';
import '../../domain/repositories/sync_repository.dart';
import '../datasources/sync_local_datasource.dart';

class SyncRepositoryImpl implements SyncRepository {
  final SyncLocalDataSource localDataSource;
  final ApiClient apiClient;
  final NetworkInfo networkInfo;

  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  SyncRepositoryImpl({
    required this.localDataSource,
    required this.apiClient,
    required this.networkInfo,
  }) {
    _refreshPendingCount();
  }

  Future<void> _refreshPendingCount() async {
    try {
      final count = await localDataSource.getPendingCount();
      if (!_pendingCountController.isClosed) {
        _pendingCountController.add(count);
      }
    } catch (_) {}
  }

  @override
  Future<void> enqueueRequest(SyncItem item) async {
    await localDataSource.enqueueItem(item);
    await _refreshPendingCount();
  }

  @override
  Future<void> enqueueSyncItem(SyncItem item) => enqueueRequest(item);

  @override
  Future<List<SyncItem>> getPendingQueue() {
    return localDataSource.getPendingItems();
  }

  @override
  Future<List<SyncItem>> getPendingItems() => getPendingQueue();

  @override
  Future<int> getPendingCount() {
    return localDataSource.getPendingCount();
  }

  @override
  Stream<int> watchPendingCount() async* {
    final initial = await localDataSource.getPendingCount();
    yield initial;
    yield* _pendingCountController.stream;
  }

  @override
  Future<void> processSyncQueue() async {
    final isOnline = await networkInfo.isConnected;
    if (!isOnline) return;

    final pending = await getPendingQueue();
    for (final item in pending) {
      await localDataSource.updateItemStatus(item.id, SyncStatus.syncing);

      try {
        dynamic data;
        try {
          data = jsonDecode(item.payloadJson);
        } catch (_) {
          data = item.payloadJson;
        }

        final response = item.httpMethod.toUpperCase() == 'POST'
            ? await apiClient.dio.post(
                item.endpoint,
                data: data,
                options: Options(
                  headers: {
                    'Idempotency-Key': item.idempotencyKey,
                  },
                ),
              )
            : await apiClient.dio.request(
                item.endpoint,
                data: data,
                options: Options(
                  method: item.httpMethod,
                  headers: {
                    'Idempotency-Key': item.idempotencyKey,
                  },
                ),
              );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await localDataSource.updateItemStatus(item.id, SyncStatus.synced);
        } else {
          await localDataSource.updateItemStatus(
            item.id,
            SyncStatus.failed,
            errorMessage: 'Status ${response.statusCode}',
          );
        }
      } catch (e) {
        await localDataSource.updateItemStatus(
          item.id,
          SyncStatus.failed,
          errorMessage: e.toString(),
        );
      }
    }

    await _refreshPendingCount();
  }

  @override
  Future<void> syncAllPending() => processSyncQueue();

  void dispose() {
    _pendingCountController.close();
  }
}
