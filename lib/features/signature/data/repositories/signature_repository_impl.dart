import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/storage/database_helper.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/mobile_sign_event.dart';
import '../../domain/repositories/signature_repository.dart';

class SignatureRepositoryImpl implements SignatureRepository {
  final ApiClient apiClient;
  final DatabaseHelper databaseHelper;
  final NetworkInfo networkInfo;

  SignatureRepositoryImpl({
    required this.apiClient,
    required this.databaseHelper,
    required this.networkInfo,
  });

  @override
  Future<Result<MobileSignEvent, Failure>> submitSignature(
    MobileSignEvent signEvent,
  ) async {
    final isOnline = await networkInfo.isConnected;

    if (isOnline) {
      try {
        final response = await apiClient.dio.post(
          '/api/v1/mobile/contracts/${signEvent.contractId}/sign',
          data: {
            'id': signEvent.id,
            'contract_id': signEvent.contractId,
            'signer_user_id': signEvent.signerUserId,
            'biometric_used': signEvent.biometricUsed,
            'signature_vector_path': signEvent.signatureVectorPath,
            'signer_ip': signEvent.signerIp,
            'gps_latitude': signEvent.gpsLatitude,
            'gps_longitude': signEvent.gpsLongitude,
            'signed_at': signEvent.signedAt.toIso8601String(),
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return Result.success(signEvent);
        } else {
          return Result.failure(
            ServerFailure(
              'Signature submission failed with status code ${response.statusCode}',
              statusCode: response.statusCode,
            ),
          );
        }
      } on ServerException catch (e) {
        return Result.failure(ServerFailure(e.message, statusCode: e.statusCode));
      } catch (e) {
        // Fallback to queue if network fails midway
        await _enqueueOfflineSignature(signEvent);
        return Result.success(signEvent);
      }
    } else {
      // Offline-first queueing
      await _enqueueOfflineSignature(signEvent);
      return Result.success(signEvent);
    }
  }

  Future<void> _enqueueOfflineSignature(MobileSignEvent signEvent) async {
    await databaseHelper.insertSyncQueueItem({
      'id': signEvent.id,
      'endpoint': '/api/v1/mobile/contracts/${signEvent.contractId}/sign',
      'method': 'POST',
      'payload': jsonEncode({
        'id': signEvent.id,
        'contract_id': signEvent.contractId,
        'signer_user_id': signEvent.signerUserId,
        'biometric_used': signEvent.biometricUsed,
        'signature_vector_path': signEvent.signatureVectorPath,
        'signer_ip': signEvent.signerIp,
        'gps_latitude': signEvent.gpsLatitude,
        'gps_longitude': signEvent.gpsLongitude,
        'signed_at': signEvent.signedAt.toIso8601String(),
      }),
      'status': 'PENDING',
      'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'idempotency_key': const Uuid().v4(),
    });
  }
}
