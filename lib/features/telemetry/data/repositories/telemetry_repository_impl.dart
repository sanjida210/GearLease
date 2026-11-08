import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/storage/database_helper.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/machine_telemetry.dart';
import '../../domain/entities/predictive_alert.dart';
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

    // 2. Stream live updates from WebSocket throttled with RxDart
    final throttledStream = wsDataSource
        .streamMachineTelemetry(assetId)
        .throttleTime(
          const Duration(milliseconds: 750),
          leading: true,
          trailing: true,
        );

    await for (final model in throttledStream) {
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
  Stream<MachineTelemetry> generateMockTelemetryStream(
    String assetId, {
    Duration period = const Duration(seconds: 1),
  }) {
    final random = math.Random();
    return Stream.periodic(period, (count) {
      final rpm = 1400.0 + random.nextInt(120) + (count % 10) * 8.0;
      final temp = 70.0 + (random.nextDouble() * 10.0);
      final vibration = 0.35 + (random.nextDouble() * 0.3);

      final MachineStatus status;
      if (temp >= 85.0 || vibration >= 1.0) {
        status = MachineStatus.fault;
      } else if (temp >= 75.0 || vibration >= 0.6) {
        status = MachineStatus.warning;
      } else {
        status = MachineStatus.optimal;
      }

      return MachineTelemetryModel(
        assetId: assetId,
        machineName: 'Equipment #$assetId',
        category: 'Heavy Equipment',
        runningHours: 1248.5 + (count * 0.1),
        temperatureCelsius: double.parse(temp.toStringAsFixed(1)),
        motorRpm: double.parse(rpm.toStringAsFixed(1)),
        vibrationG: double.parse(vibration.toStringAsFixed(2)),
        status: status,
        currentBillingCents: 112000,
        billingType: 'Revenue-Indexed',
        timestamp: DateTime.now(),
      );
    });
  }

  @override
  Future<Result<List<PredictiveAlert>, Failure>> getActiveAlerts(String assetId) async {
    final isOnline = await networkInfo.isConnected;
    if (isOnline) {
      try {
        final response = await apiClient.dio.get('/api/v1/telemetry/assets/$assetId/alerts');
        if (response.statusCode == 200 && response.data is List) {
          final list = (response.data as List).map((item) {
            final map = item as Map<String, dynamic>;
            return PredictiveAlert(
              alertId: map['alert_id'] as String? ?? 'alt-001',
              assetId: assetId,
              severity: AlertSeverity.fromString(map['severity'] as String?),
              title: map['title'] as String? ?? 'Telemetry Warning',
              description: map['description'] as String? ?? 'Telemetry threshold alert',
              suggestedAction: map['suggested_action'] as String? ?? 'Inspect machine status',
              timestamp: map['timestamp'] != null
                  ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
                  : DateTime.now(),
            );
          }).toList();
          return Result.success(list);
        }
      } catch (_) {
        // Fallback to local evaluation
      }
    }

    // Local / cached alert evaluation fallback
    try {
      final cached = await databaseHelper.getTelemetry(assetId);
      final temp = (cached?['temp_celsius'] as num? ?? 0.0).toDouble();
      final alerts = <PredictiveAlert>[];
      if (temp >= 75.0) {
        alerts.add(PredictiveAlert(
          alertId: 'alt-$assetId-temp',
          assetId: assetId,
          severity: temp >= 85.0 ? AlertSeverity.CRITICAL : AlertSeverity.HIGH,
          title: 'High Thermal Drift Detected',
          description: 'Machine temperature ($temp°C) exceeds optimal threshold.',
          suggestedAction: 'Schedule precision lubrication or check cooling system.',
          timestamp: DateTime.now(),
        ));
      }
      return Result.success(alerts);
    } catch (e) {
      return Result.success(const []);
    }
  }

  @override
  Future<Result<void, Failure>> requestMaintenanceService(String assetId, String alertId) async {
    final isOnline = await networkInfo.isConnected;
    if (isOnline) {
      try {
        final response = await apiClient.dio.post(
          '/api/v1/telemetry/assets/$assetId/maintenance-request',
          data: {
            'asset_id': assetId,
            'alert_id': alertId,
            'requested_at': DateTime.now().toIso8601String(),
          },
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          return Result.success(null);
        }
      } catch (_) {
        await _enqueueMaintenanceRequest(assetId, alertId);
        return Result.success(null);
      }
    }
    await _enqueueMaintenanceRequest(assetId, alertId);
    return Result.success(null);
  }

  Future<void> _enqueueMaintenanceRequest(String assetId, String alertId) async {
    await databaseHelper.insertSyncQueueItem({
      'id': const Uuid().v4(),
      'endpoint': '/api/v1/telemetry/assets/$assetId/maintenance-request',
      'method': 'POST',
      'payload': jsonEncode({
        'asset_id': assetId,
        'alert_id': alertId,
        'requested_at': DateTime.now().toIso8601String(),
      }),
      'status': 'PENDING',
      'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'idempotency_key': const Uuid().v4(),
    });
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
