import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/features/offline_sync/domain/entities/sync_item.dart';
import 'package:gearlease/features/offline_sync/domain/repositories/sync_repository.dart';

class FakeSyncRepository implements SyncRepository {
  final List<SyncItem> queue = [];
  final StreamController<int> _countController = StreamController<int>.broadcast();
  bool processQueueCalled = false;

  @override
  Future<void> enqueueRequest(SyncItem item) async {
    queue.add(item);
    _countController.add(queue.length);
  }

  @override
  Future<List<SyncItem>> getPendingQueue() async {
    return List.unmodifiable(queue);
  }

  @override
  Future<void> processSyncQueue() async {
    processQueueCalled = true;
    queue.clear();
    _countController.add(0);
  }

  @override
  Stream<int> watchPendingCount() {
    late StreamController<int> controller;
    StreamSubscription<int>? sub;
    controller = StreamController<int>(
      onListen: () {
        controller.add(queue.length);
        sub = _countController.stream.listen(controller.add);
      },
      onCancel: () {
        sub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> enqueueSyncItem(SyncItem item) => enqueueRequest(item);

  @override
  Future<List<SyncItem>> getPendingItems() => getPendingQueue();

  @override
  Future<int> getPendingCount() async => queue.length;

  @override
  Future<void> syncAllPending() => processSyncQueue();

  void dispose() {
    _countController.close();
  }
}

void main() {
  group('Phase 25: SyncItem Domain Entity Specifications', () {
    final now = DateTime.parse('2026-11-09T00:00:00Z');

    test('supports all 4 sync statuses: QUEUED, PROCESSING, SYNCED, CONFLICT_REJECTED', () {
      expect(SyncItemStatus.QUEUED.code, equals('QUEUED'));
      expect(SyncItemStatus.PROCESSING.code, equals('PROCESSING'));
      expect(SyncItemStatus.SYNCED.code, equals('SYNCED'));
      expect(SyncItemStatus.CONFLICT_REJECTED.code, equals('CONFLICT_REJECTED'));

      expect(SyncItemStatus.fromString('QUEUED'), equals(SyncItemStatus.QUEUED));
      expect(SyncItemStatus.fromString('processing'), equals(SyncItemStatus.PROCESSING));
      expect(SyncItemStatus.fromString('SYNCED'), equals(SyncItemStatus.SYNCED));
      expect(SyncItemStatus.fromString('CONFLICT_REJECTED'), equals(SyncItemStatus.CONFLICT_REJECTED));
    });

    test('instantiates with all Phase 25 required fields and verifies defaults', () {
      final item = SyncItem(
        id: '550e8400-e29b-41d4-a716-446655440000',
        endpoint: '/api/v1/leases/sign',
        httpMethod: 'POST',
        payloadJson: '{"lease_id":"ls_123","amount":15000}',
        mediaFilePaths: const ['/storage/sig_01.png', '/storage/angle_01.jpg'],
        status: SyncItemStatus.QUEUED,
        retryCount: 0,
        createdAt: now,
        idempotencyKey: 'idem-uuid-999',
      );

      expect(item.id, equals('550e8400-e29b-41d4-a716-446655440000'));
      expect(item.endpoint, equals('/api/v1/leases/sign'));
      expect(item.httpMethod, equals('POST'));
      expect(item.payloadJson, equals('{"lease_id":"ls_123","amount":15000}'));
      expect(item.mediaFilePaths, equals(['/storage/sig_01.png', '/storage/angle_01.jpg']));
      expect(item.status, equals(SyncItemStatus.QUEUED));
      expect(item.retryCount, equals(0));
      expect(item.createdAt, equals(now));
      expect(item.idempotencyKey, equals('idem-uuid-999'));
    });

    test('supports value equality via Equatable', () {
      final item1 = SyncItem(
        id: '550e8400-e29b-41d4-a716-446655440000',
        endpoint: '/api/v1/leases/sign',
        httpMethod: 'POST',
        payloadJson: '{"amount":5000}',
        mediaFilePaths: const ['/img/1.png'],
        status: SyncItemStatus.QUEUED,
        retryCount: 0,
        createdAt: now,
        idempotencyKey: 'key_1',
      );

      final item2 = SyncItem(
        id: '550e8400-e29b-41d4-a716-446655440000',
        endpoint: '/api/v1/leases/sign',
        httpMethod: 'POST',
        payloadJson: '{"amount":5000}',
        mediaFilePaths: const ['/img/1.png'],
        status: SyncItemStatus.QUEUED,
        retryCount: 0,
        createdAt: now,
        idempotencyKey: 'key_1',
      );

      expect(item1, equals(item2));
    });

    test('copyWith updates fields including status, retryCount, and mediaFilePaths', () {
      final item = SyncItem(
        id: 'sync_001',
        endpoint: '/api/v1/mobile/quotes',
        payloadJson: '{}',
        createdAt: now,
        idempotencyKey: 'idem_01',
      );

      final updated = item.copyWith(
        status: SyncItemStatus.PROCESSING,
        retryCount: 2,
        mediaFilePaths: ['/cached/doc.pdf'],
      );

      expect(updated.status, equals(SyncItemStatus.PROCESSING));
      expect(updated.retryCount, equals(2));
      expect(updated.mediaFilePaths, equals(['/cached/doc.pdf']));
      expect(updated.id, equals(item.id));
      expect(updated.endpoint, equals(item.endpoint));
    });

    test('toJson and fromJson correctly serialize and deserialize SyncItem', () {
      final item = SyncItem(
        id: 'uuid-item-123',
        endpoint: '/api/v1/telemetry/alert',
        httpMethod: 'PUT',
        payloadJson: '{"acknowledged":true}',
        mediaFilePaths: const ['/log/dump.txt'],
        status: SyncItemStatus.CONFLICT_REJECTED,
        retryCount: 3,
        createdAt: now,
        idempotencyKey: 'key-abc-777',
      );

      final json = item.toJson();
      expect(json['id'], equals('uuid-item-123'));
      expect(json['endpoint'], equals('/api/v1/telemetry/alert'));
      expect(json['http_method'], equals('PUT'));
      expect(json['payload_json'], equals('{"acknowledged":true}'));
      expect(json['media_file_paths'], equals(['/log/dump.txt']));
      expect(json['status'], equals('CONFLICT_REJECTED'));
      expect(json['retry_count'], equals(3));
      expect(json['created_at'], equals(now.toIso8601String()));
      expect(json['idempotency_key'], equals('key-abc-777'));

      final fromJson = SyncItem.fromJson(json);
      expect(fromJson, equals(item));
    });
  });

  group('Phase 25: SyncRepository Domain Interface Specifications', () {
    late FakeSyncRepository repository;

    setUp(() {
      repository = FakeSyncRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('enqueueRequest adds item and updates pending count', () async {
      final item = SyncItem(
        id: 'item_req_1',
        endpoint: '/api/v1/leases/sign',
        payloadJson: '{"lease_id":"ls_1"}',
        createdAt: DateTime.now(),
        idempotencyKey: 'idem_1',
      );

      await repository.enqueueRequest(item);

      final queue = await repository.getPendingQueue();
      expect(queue.length, equals(1));
      expect(queue.first.id, equals('item_req_1'));
    });

    test('processSyncQueue triggers sync and empties queue', () async {
      final item = SyncItem(
        id: 'item_req_2',
        endpoint: '/api/v1/assets/inspect',
        payloadJson: '{}',
        createdAt: DateTime.now(),
        idempotencyKey: 'idem_2',
      );

      await repository.enqueueRequest(item);
      expect((await repository.getPendingQueue()).length, equals(1));

      await repository.processSyncQueue();

      expect(repository.processQueueCalled, isTrue);
      expect((await repository.getPendingQueue()).isEmpty, isTrue);
    });

    test('watchPendingCount emits count stream updates upon enqueue and process', () async {
      final item = SyncItem(
        id: 'item_req_3',
        endpoint: '/api/v1/quote',
        payloadJson: '{}',
        createdAt: DateTime.now(),
        idempotencyKey: 'idem_3',
      );

      final streamExpectation = expectLater(
        repository.watchPendingCount(),
        emitsInOrder([0, 1, 0]),
      );

      await repository.enqueueRequest(item);
      await repository.processSyncQueue();

      await streamExpectation;
    });
  });
}
