import 'package:equatable/equatable.dart';

class MobileSignEvent extends Equatable {
  final String id;
  final String contractId;
  final String signerUserId;
  final String? biometricUsed;
  final String signatureVectorPath;
  final String signerIp;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final DateTime signedAt;
  final String? auditHash;
  final Map<String, dynamic>? metadata;

  const MobileSignEvent({
    required this.id,
    required this.contractId,
    required this.signerUserId,
    this.biometricUsed,
    required this.signatureVectorPath,
    required this.signerIp,
    this.gpsLatitude,
    this.gpsLongitude,
    required this.signedAt,
    this.auditHash,
    this.metadata,
  });

  @override
  List<Object?> get props => [
        id,
        contractId,
        signerUserId,
        biometricUsed,
        signatureVectorPath,
        signerIp,
        gpsLatitude,
        gpsLongitude,
        signedAt,
        auditHash,
        metadata,
      ];
}
