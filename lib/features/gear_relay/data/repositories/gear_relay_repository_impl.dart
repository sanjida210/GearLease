import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/storage/database_helper.dart';
import '../../domain/entities/inspection_angle.dart';
import '../../domain/repositories/gear_relay_repository.dart';
import '../services/image_compression_service.dart';

class GearRelayRepositoryImpl implements GearRelayRepository {
  final ApiClient apiClient;
  final DatabaseHelper databaseHelper;
  final NetworkInfo networkInfo;
  final ImageCompressionService compressionService;

  GearRelayRepositoryImpl({
    required this.apiClient,
    required this.databaseHelper,
    required this.networkInfo,
    required this.compressionService,
  });

  @override
  Future<String> submitInspectionBundle({
    required String assetId,
    required List<InspectionAngle> angles,
    double? latitude,
    double? longitude,
  }) async {
    final List<Map<String, dynamic>> processedAngles = [];

    for (final angle in angles) {
      String path = angle.localFilePath ?? '';
      if (path.isNotEmpty) {
        path = await compressionService.compressImage(path);
      }
      processedAngles.add({
        'angle_type': angle.type.name,
        'title': angle.title,
        'image_path': path,
        'is_captured': angle.isCaptured,
      });
    }

    final isOnline = await networkInfo.isConnected;
    final bundleId = const Uuid().v4();

    if (isOnline) {
      try {
        final response = await apiClient.dio.post(
          '/api/v1/mobile/assets/inspection-bundle',
          data: {
            'bundle_id': bundleId,
            'asset_id': assetId,
            'recorded_at': DateTime.now().toIso8601String(),
            'angles': processedAngles,
            'gps_latitude': latitude ?? 37.7749,
            'gps_longitude': longitude ?? -122.4194,
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.data;
          if (data is Map && data.containsKey('valuation_id')) {
            return data['valuation_id'] as String;
          }
          return 'cpo_val_${bundleId.substring(0, 8)}';
        }
      } catch (_) {
        // Fall back to offline queue
        await _enqueueOfflineBundle(bundleId, assetId, processedAngles, latitude, longitude);
        return 'offline_cpo_${bundleId.substring(0, 8)}';
      }
    }

    await _enqueueOfflineBundle(bundleId, assetId, processedAngles, latitude, longitude);
    return 'offline_cpo_${bundleId.substring(0, 8)}';
  }

  Future<void> _enqueueOfflineBundle(
    String bundleId,
    String assetId,
    List<Map<String, dynamic>> angles,
    double? latitude,
    double? longitude,
  ) async {
    await databaseHelper.insertSyncQueueItem({
      'id': bundleId,
      'endpoint': '/api/v1/mobile/assets/inspection-bundle',
      'method': 'POST',
      'payload': jsonEncode({
        'bundle_id': bundleId,
        'asset_id': assetId,
        'recorded_at': DateTime.now().toIso8601String(),
        'angles': angles,
        'gps_latitude': latitude ?? 37.7749,
        'gps_longitude': longitude ?? -122.4194,
      }),
      'status': 'PENDING',
      'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'idempotency_key': const Uuid().v4(),
    });
  }
}
