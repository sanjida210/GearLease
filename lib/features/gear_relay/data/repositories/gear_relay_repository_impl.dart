import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/storage/database_helper.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/return_inspection.dart';
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
  Future<Result<ReturnInspection, Failure>> submitInspectionBundle(
    String leaseId,
    Map<String, String> photoPaths, {
    double? latitude,
    double? longitude,
  }) async {
    final Map<String, String> compressedPhotos = {};

    for (final entry in photoPaths.entries) {
      String path = entry.value;
      if (path.isNotEmpty) {
        path = await compressionService.compressImage(path);
      }
      compressedPhotos[entry.key] = path;
    }

    final isOnline = await networkInfo.isConnected;
    final bundleId = const Uuid().v4();

    final payload = {
      'bundle_id': bundleId,
      'lease_id': leaseId,
      'asset_id': leaseId,
      'recorded_at': DateTime.now().toIso8601String(),
      'photo_paths': compressedPhotos,
      'gps_latitude': latitude ?? 37.7749,
      'gps_longitude': longitude ?? -122.4194,
    };

    if (isOnline) {
      try {
        final response = await apiClient.dio.post(
          '/api/v1/mobile/assets/inspection-bundle',
          data: payload,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.data;
          String inspectionId = 'cpo_val_${bundleId.substring(0, 8)}';
          ReturnInspectionGrade grade = ReturnInspectionGrade.A_EXCELLENT;

          if (data is Map) {
            inspectionId = data['inspection_id'] as String? ??
                data['valuation_id'] as String? ??
                inspectionId;
            if (data.containsKey('overall_grade')) {
              grade = ReturnInspectionGrade.fromString(data['overall_grade'] as String);
            }
          }

          return Result.success(ReturnInspection(
            inspectionId: inspectionId,
            leaseId: leaseId,
            assetId: leaseId,
            inspectionDate: DateTime.now(),
            overallGrade: grade,
            photoPaths: compressedPhotos,
          ));
        } else {
          return Result.failure(ServerFailure(
            'Inspection submission failed with status code ${response.statusCode}',
            statusCode: response.statusCode,
          ));
        }
      } catch (e) {
        // Fall back to offline queue
        await _enqueueOfflineBundle(bundleId, leaseId, compressedPhotos, latitude, longitude);
        return Result.success(ReturnInspection(
          inspectionId: 'offline_cpo_${bundleId.substring(0, 8)}',
          leaseId: leaseId,
          assetId: leaseId,
          inspectionDate: DateTime.now(),
          overallGrade: ReturnInspectionGrade.A_EXCELLENT,
          photoPaths: compressedPhotos,
        ));
      }
    }

    await _enqueueOfflineBundle(bundleId, leaseId, compressedPhotos, latitude, longitude);
    return Result.success(ReturnInspection(
      inspectionId: 'offline_cpo_${bundleId.substring(0, 8)}',
      leaseId: leaseId,
      assetId: leaseId,
      inspectionDate: DateTime.now(),
      overallGrade: ReturnInspectionGrade.A_EXCELLENT,
      photoPaths: compressedPhotos,
    ));
  }

  Future<void> _enqueueOfflineBundle(
    String bundleId,
    String leaseId,
    Map<String, String> photoPaths,
    double? latitude,
    double? longitude,
  ) async {
    await databaseHelper.insertSyncQueueItem({
      'id': bundleId,
      'endpoint': '/api/v1/mobile/assets/inspection-bundle',
      'method': 'POST',
      'payload': jsonEncode({
        'bundle_id': bundleId,
        'lease_id': leaseId,
        'asset_id': leaseId,
        'recorded_at': DateTime.now().toIso8601String(),
        'photo_paths': photoPaths,
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
