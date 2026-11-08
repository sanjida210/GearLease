import 'dart:typed_data';
import 'package:equatable/equatable.dart';

class SignaturePayloadBundle extends Equatable {
  final String leaseId;
  final String agentId;
  final String hash;
  final String utcTimestampIso;
  final int strokeCount;
  final int durationMs;
  final String platform;
  final Uint8List pngBytes;
  final String signatureSvg;
  final Map<String, dynamic> metadata;

  const SignaturePayloadBundle({
    required this.leaseId,
    required this.agentId,
    required this.hash,
    required this.utcTimestampIso,
    required this.strokeCount,
    required this.durationMs,
    required this.platform,
    required this.pngBytes,
    required this.signatureSvg,
    required this.metadata,
  });

  String get contractId => leaseId;

  @override
  List<Object?> get props => [
        leaseId,
        agentId,
        hash,
        utcTimestampIso,
        strokeCount,
        durationMs,
        platform,
        pngBytes,
        signatureSvg,
        metadata,
      ];
}
