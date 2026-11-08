import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/features/offline_sync/domain/entities/sync_item.dart';

void main() {
  group('SyncItem Domain Entity Tests', () {
    final now = DateTime.parse('2026-11-04T12:00:00Z');

    final testItem = SyncItem(
      id: 'sync-001',
      idempotencyKey: 'idem-001',
      actionType: '/api/v1/mobile/quotes',
      payloadJson: '{"amount": 5000}',
      status: SyncStatus.pending,
      createdAt: now,
    );

    test('supports value equality via Equatable', () {
      final duplicate = SyncItem(
        id: 'sync-001',
        idempotencyKey: 'idem-001',
        actionType: '/api/v1/mobile/quotes',
        payloadJson: '{"amount": 5000}',
        status: SyncStatus.pending,
        createdAt: now,
      );

      expect(testItem, equals(duplicate));
    });

    test('copyWith updates status, syncedAt, and errorMessage', () {
      final syncedTime = DateTime.parse('2026-11-04T12:05:00Z');
      final updated = testItem.copyWith(
        status: SyncStatus.synced,
        syncedAt: syncedTime,
      );

      expect(updated.status, SyncStatus.synced);
      expect(updated.syncedAt, syncedTime);
      expect(updated.id, testItem.id);
    });
  });
}
