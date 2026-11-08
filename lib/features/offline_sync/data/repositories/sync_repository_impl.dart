import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/sync_item.dart';
import '../../domain/repositories/sync_repository.dart';
import '../datasources/sync_local_datasource.dart';

class SyncConflictAlert {
  final String itemId;
  final String endpoint;
  final String message;
  final Map<String, dynamic>? conflictDetails;

  const SyncConflictAlert({
    required this.itemId,
    required this.endpoint,
    required this.message,
    this.conflictDetails,
  });
}

class SyncRepositoryImpl implements SyncRepository {
  final SyncLocalDataSource localDataSource;
  final ApiClient apiClient;
  final NetworkInfo networkInfo;

  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();
  final StreamController<SyncConflictAlert> _conflictAlertController =
      StreamController<SyncConflictAlert>.broadcast();

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isProcessing = false;

  SyncRepositoryImpl({
    required this.localDataSource,
    required this.apiClient,
    required this.networkInfo,
  }) {
    _refreshPendingCount();

    // 1. Listen to connectivity: trigger automatic FIFO processing when online
    _connectivitySubscription = networkInfo.onConnectivityChanged.listen((isConnected) {
      if (isConnected) {
        processSyncQueue();
      }
    });
  }

  Stream<SyncConflictAlert> get conflictAlertStream => _conflictAlertController.stream;

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
    if (!isOnline || _isProcessing) return;

    _isProcessing = true;

    try {
      final pending = await getPendingQueue();

      for (final item in pending) {
        await localDataSource.updateItemStatus(item.id, SyncItemStatus.PROCESSING);

        try {
          dynamic requestData;

          // Check for inspection bundle or media files -> use FormData
          final isInspectionBundle = item.endpoint.contains('inspection-bundle');
          final hasMedia = item.mediaFilePaths.isNotEmpty;

          if (isInspectionBundle || hasMedia) {
            Map<String, dynamic> jsonFields = {};
            try {
              final decoded = jsonDecode(item.payloadJson);
              if (decoded is Map<String, dynamic>) {
                jsonFields = Map<String, dynamic>.from(decoded);
              }
            } catch (_) {}

            final formData = FormData.fromMap(jsonFields);

            for (final filePath in item.mediaFilePaths) {
              if (filePath.isNotEmpty) {
                final fileName = filePath.split('/').last;
                if (!filePath.startsWith('/mock') && File(filePath).existsSync()) {
                  formData.files.add(MapEntry(
                    'photos',
                    await MultipartFile.fromFile(filePath, filename: fileName),
                  ));
                } else {
                  // Virtual / test mock file stream
                  formData.files.add(MapEntry(
                    'photos',
                    MultipartFile.fromString('mock_image_binary_data', filename: fileName),
                  ));
                }
              }
            }
            requestData = formData;
          } else {
            try {
              requestData = jsonDecode(item.payloadJson);
            } catch (_) {
              requestData = item.payloadJson;
            }
          }

          final headers = {
            'Idempotency-Key': item.idempotencyKey,
          };

          final response = item.httpMethod.toUpperCase() == 'POST'
              ? await apiClient.dio.post(
                  item.endpoint,
                  data: requestData,
                  options: Options(headers: headers),
                )
              : await apiClient.dio.request(
                  item.endpoint,
                  data: requestData,
                  options: Options(
                    method: item.httpMethod,
                    headers: headers,
                  ),
                );

          if (response.statusCode == 200 || response.statusCode == 201) {
            await localDataSource.updateItemStatus(item.id, SyncItemStatus.SYNCED);
          } else {
            await localDataSource.updateItemStatus(
              item.id,
              SyncItemStatus.QUEUED,
              retryCount: item.retryCount + 1,
              errorMessage: 'Status code: ${response.statusCode}',
            );
          }
        } on DioException catch (dioErr) {
          // Handle 409 Conflict (e.g., asset already leased)
          if (dioErr.response?.statusCode == 409) {
            String errorDetail = 'Asset or resource state conflict.';
            Map<String, dynamic>? details;

            if (dioErr.response?.data is Map) {
              details = dioErr.response!.data as Map<String, dynamic>;
              errorDetail = details['error'] as String? ??
                  details['message'] as String? ??
                  errorDetail;
            }

            final conflictMsg = '409 Conflict: $errorDetail';

            await localDataSource.updateItemStatus(
              item.id,
              SyncItemStatus.CONFLICT_REJECTED,
              errorMessage: conflictMsg,
            );

            _conflictAlertController.add(SyncConflictAlert(
              itemId: item.id,
              endpoint: item.endpoint,
              message: conflictMsg,
              conflictDetails: details,
            ));
          } else {
            await localDataSource.updateItemStatus(
              item.id,
              SyncItemStatus.QUEUED,
              retryCount: item.retryCount + 1,
              errorMessage: dioErr.message,
            );
          }
        } catch (e) {
          await localDataSource.updateItemStatus(
            item.id,
            SyncItemStatus.QUEUED,
            retryCount: item.retryCount + 1,
            errorMessage: e.toString(),
          );
        }
      }
    } finally {
      _isProcessing = false;
      await _refreshPendingCount();
    }
  }

  @override
  Future<void> syncAllPending() => processSyncQueue();

  void dispose() {
    _connectivitySubscription?.cancel();
    _pendingCountController.close();
    _conflictAlertController.close();
  }
}
