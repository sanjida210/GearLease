import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/features/signature/domain/entities/signature_payload_bundle.dart';
import 'package:gearlease/features/signature/domain/services/signature_audit_generator.dart';

void main() {
  group('SignatureAuditGenerator Unit Tests', () {
    const testLeaseId = 'lease-889922';
    const testAgentId = 'agent-007';
    const testTimestampIso = '2026-11-08T22:00:00.000Z';
    final testSignatureBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02, 0x03]);

    test('generateSha256Hash produces valid SHA-256 hash from bytes + leaseId + agentId + timestamp', () {
      final hash = SignatureAuditGenerator.generateSha256Hash(
        signatureBytes: testSignatureBytes,
        leaseId: testLeaseId,
        agentId: testAgentId,
        utcTimestampIso: testTimestampIso,
      );

      // Verify calculation manually
      final expectedInput = <int>[
        ...testSignatureBytes,
        ...utf8.encode(testLeaseId),
        ...utf8.encode(testAgentId),
        ...utf8.encode(testTimestampIso),
      ];
      final expectedHash = sha256.convert(expectedInput).toString();

      expect(hash, equals(expectedHash));
      expect(hash.length, 64); // Standard SHA-256 hex string length
    });

    test('packageMetadata produces expected audit structure', () {
      const hash = 'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e';
      final metadata = SignatureAuditGenerator.packageMetadata(
        hash: hash,
        utcTimestampIso: testTimestampIso,
        strokeCount: 42,
        platform: 'android',
        durationMs: 3450,
      );

      expect(metadata['hash'], hash);
      expect(metadata['timestamp'], testTimestampIso);
      expect(metadata['stroke_count'], 42);
      expect(metadata['platform'], 'android');
      expect(metadata['duration_ms'], 3450);
    });

    test('SignaturePayloadBundle supports Equatable value equality', () {
      final bundle1 = SignaturePayloadBundle(
        leaseId: testLeaseId,
        agentId: testAgentId,
        hash: 'hash-abc',
        utcTimestampIso: testTimestampIso,
        strokeCount: 20,
        durationMs: 1200,
        platform: 'ios',
        pngBytes: testSignatureBytes,
        signatureSvg: '<svg></svg>',
        metadata: const {'hash': 'hash-abc', 'stroke_count': 20},
      );

      final bundle2 = SignaturePayloadBundle(
        leaseId: testLeaseId,
        agentId: testAgentId,
        hash: 'hash-abc',
        utcTimestampIso: testTimestampIso,
        strokeCount: 20,
        durationMs: 1200,
        platform: 'ios',
        pngBytes: testSignatureBytes,
        signatureSvg: '<svg></svg>',
        metadata: const {'hash': 'hash-abc', 'stroke_count': 20},
      );

      expect(bundle1, equals(bundle2));
    });
  });
}
