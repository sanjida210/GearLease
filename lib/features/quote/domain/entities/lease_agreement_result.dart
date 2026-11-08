import 'package:equatable/equatable.dart';

class LeaseAgreementResult extends Equatable {
  final String leaseId;
  final String status;
  final String? pdfUrl;
  final String idempotencyKey;
  final bool isOfflineQueued;
  final DateTime submittedAt;

  const LeaseAgreementResult({
    required this.leaseId,
    required this.status,
    this.pdfUrl,
    required this.idempotencyKey,
    required this.isOfflineQueued,
    required this.submittedAt,
  });

  @override
  List<Object?> get props => [
        leaseId,
        status,
        pdfUrl,
        idempotencyKey,
        isOfflineQueued,
        submittedAt,
      ];
}
