import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/storage/database_helper.dart';
import '../../domain/entities/machine_telemetry.dart';
import '../../domain/repositories/telemetry_repository.dart';
import '../datasources/telemetry_ws_datasource.dart';
import '../models/machine_telemetry_model.dart';

class TelemetryRepositoryImpl implements TelemetryRepository {
  final TelemetryWsDataSource wsDataSource;
  final DatabaseHelper databaseHelper;
  final ApiClient apiClient;
  final NetworkInfo networkInfo;

  TelemetryRepositoryImpl({
    required this.wsDataSource,
    required this.databaseHelper,
    required this.apiClient,
    required this.networkInfo,
  });

  @override
  Stream<MachineTelemetry> watchMachineTelemetry(String assetId) async* {
    // 1. Emit cached telemetry first if available
    try {
      final cached = await databaseHelper.getTelemetry(assetId);
      if (cached != null) {
        yield MachineTelemetryModel.fromDbMap(cached);
      }
    } catch (_) {}

    // 2. Stream live updates from WebSocket
    await for (final model in wsDataSource.streamMachineTelemetry(assetId)) {
      try {
        await databaseHelper.upsertTelemetry(model.toDbMap());
      } catch (_) {}
      yield model;
    }
  }

  @override
  Stream<List<MachineTelemetry>> watchFleetTelemetry() {
    return wsDataSource.streamFleetTelemetry();
  }

  @override
  Future<bool> scheduleWarrantyService(String assetId, String notes) async {
    final isOnline = await networkInfo.isConnected;

    if (isOnline) {
      try {
        final response = await apiClient.dio.post(
          '/api/v1/telemetry/assets/$assetId/service-request',
          data: {
            'asset_id': assetId,
            'notes': notes,
            'requested_at': DateTime.now().toIso8601String(),
          },
        );
        return response.statusCode == 200 || response.statusCode == 201;
      } catch (_) {
        await _enqueueServiceRequest(assetId, notes);
        return true;
      }
    } else {
      await _enqueueServiceRequest(assetId, notes);
      return true;
    }
  }

  Future<void> _enqueueServiceRequest(String assetId, String notes) async {
    await databaseHelper.insertSyncQueueItem({
      'id': const Uuid().v4(),
      'endpoint': '/api/v1/telemetry/assets/$assetId/service-request',
      'method': 'POST',
      'payload': jsonEncode({
        'asset_id': assetId,
        'notes': notes,
        'requested_at': DateTime.now().toIso8601String(),
      }),
      'status': 'PENDING',
      'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'idempotency_key': const Uuid().v4(),
    });
  }
}
