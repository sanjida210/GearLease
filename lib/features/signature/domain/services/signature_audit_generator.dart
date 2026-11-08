import 'dart:convert';
import 'package:crypto/crypto.dart';

class SignatureAuditGenerator {
  const SignatureAuditGenerator._();

  /// Generates a SHA-256 cryptographic audit hash of:
  /// Signature Bytes + Lease ID + Agent ID + UTC Timestamp.
  static String generateSha256Hash({
    required List<int> signatureBytes,
    required String leaseId,
    required String agentId,
    required String utcTimestampIso,
  }) {
    final bytesToHash = <int>[
      ...signatureBytes,
      ...utf8.encode(leaseId),
      ...utf8.encode(agentId),
      ...utf8.encode(utcTimestampIso),
    ];
    return sha256.convert(bytesToHash).toString();
  }

  /// Packages signature metadata: `{hash, timestamp, stroke_count, platform, duration_ms}`.
  static Map<String, dynamic> packageMetadata({
    required String hash,
    required String utcTimestampIso,
    required int strokeCount,
    required String platform,
    int? durationMs,
  }) {
    return {
      'hash': hash,
      'timestamp': utcTimestampIso,
      'stroke_count': strokeCount,
      'platform': platform,
      if (durationMs != null) 'duration_ms': durationMs,
    };
  }
}
