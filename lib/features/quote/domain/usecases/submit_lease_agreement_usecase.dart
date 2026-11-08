import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/result.dart';
import '../../../offline_sync/domain/entities/sync_item.dart';
import '../../../offline_sync/domain/repositories/sync_repository.dart';
import '../entities/lease_agreement_result.dart';

class SubmitLeaseAgreementParams extends Equatable {
  final String quoteId;
  final String lesseeBusinessName;
  final String equipmentSerial;
  final int termMonths;
  final int monthlyBaseCents;
  final String pricingType;
  final String auditHash;
  final Uint8List signatureBytes;
  final String? signatureSvg;
  final String? businessEin;
  final Map<String, dynamic>? metadata;

  const SubmitLeaseAgreementParams({
    required this.quoteId,
    required this.lesseeBusinessName,
    required this.equipmentSerial,
    required this.termMonths,
    required this.monthlyBaseCents,
    required this.pricingType,
    required this.auditHash,
    required this.signatureBytes,
    this.signatureSvg,
    this.businessEin,
    this.metadata,
  });

  @override
  List<Object?> get props => [
        quoteId,
        lesseeBusinessName,
        equipmentSerial,
        termMonths,
        monthlyBaseCents,
        pricingType,
        auditHash,
        signatureBytes,
        signatureSvg,
        businessEin,
        metadata,
      ];
}

class SubmitLeaseAgreementUseCase {
  final ApiClient apiClient;
  final SyncRepository syncRepository;
  final NetworkInfo networkInfo;

  SubmitLeaseAgreementUseCase({
    required this.apiClient,
    required this.syncRepository,
    required this.networkInfo,
  });

  Future<Result<LeaseAgreementResult, Failure>> call(
    SubmitLeaseAgreementParams params,
  ) async {
    final idempotencyKey = const Uuid().v4();
    final isConnected = await networkInfo.isConnected;

    final payload = {
      'idempotency_key': idempotencyKey,
      'quote_id': params.quoteId,
      'lessee_business_name': params.lesseeBusinessName,
      'business_ein': params.businessEin,
      'equipment_serial': params.equipmentSerial,
      'term_months': params.termMonths,
      'monthly_base_cents': params.monthlyBaseCents,
      'pricing_type': params.pricingType,
      'audit_hash': params.auditHash,
      'signature_base64': base64Encode(params.signatureBytes),
      if (params.signatureSvg != null) 'signature_svg': params.signatureSvg,
      if (params.metadata != null) 'metadata': params.metadata,
    };

    if (isConnected) {
      try {
        final response = await apiClient.dio.post(
          '/api/v1/leases/sign',
          data: payload,
          options: Options(
            headers: {
              'Idempotency-Key': idempotencyKey,
            },
          ),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : <String, dynamic>{};

          final leaseId = data['lease_id'] as String? ??
              'LSE-${const Uuid().v4().substring(0, 8).toUpperCase()}';
          final status = data['status'] as String? ?? 'EXECUTED';
          final pdfUrl = data['pdf_url'] as String? ??
              'https://api.gearlease.io/leases/$leaseId/document.pdf';

          return Result.success(
            LeaseAgreementResult(
              leaseId: leaseId,
              status: status,
              pdfUrl: pdfUrl,
              idempotencyKey: idempotencyKey,
              isOfflineQueued: false,
              submittedAt: DateTime.now().toUtc(),
            ),
          );
        } else {
          return Result.failure(
            ServerFailure(
              'Failed to execute lease agreement with status: ${response.statusCode}',
            ),
          );
        }
      } on DioException catch (dioError) {
        // If network connectivity dropped during request, forward to offline queue
        if (dioError.type == DioExceptionType.connectionError ||
            dioError.type == DioExceptionType.connectionTimeout) {
          return _enqueueOffline(idempotencyKey, payload);
        }
        return Result.failure(ServerFailure(dioError.message ?? 'Server error'));
      } catch (e) {
        return _enqueueOffline(idempotencyKey, payload);
      }
    } else {
      return _enqueueOffline(idempotencyKey, payload);
    }
  }

  Future<Result<LeaseAgreementResult, Failure>> _enqueueOffline(
    String idempotencyKey,
    Map<String, dynamic> payload,
  ) async {
    final syncItem = SyncItem(
      id: const Uuid().v4(),
      idempotencyKey: idempotencyKey,
      actionType: 'SUBMIT_LEASE_AGREEMENT',
      payloadJson: jsonEncode(payload),
      status: SyncStatus.pending,
      createdAt: DateTime.now().toUtc(),
    );

    await syncRepository.enqueueSyncItem(syncItem);

    final offlineLeaseId = 'OFFLINE-${idempotencyKey.substring(0, 8).toUpperCase()}';

    return Result.success(
      LeaseAgreementResult(
        leaseId: offlineLeaseId,
        status: 'QUEUED_OFFLINE',
        pdfUrl: null,
        idempotencyKey: idempotencyKey,
        isOfflineQueued: true,
        submittedAt: DateTime.now().toUtc(),
      ),
    );
  }
}
