import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/features/offline_sync/domain/entities/sync_item.dart';
import 'package:gearlease/features/offline_sync/domain/repositories/sync_repository.dart';
import 'package:gearlease/features/offline_sync/presentation/bloc/sync_bloc.dart';
import 'package:gearlease/features/offline_sync/presentation/bloc/sync_event.dart';
import 'package:gearlease/features/offline_sync/presentation/bloc/sync_state.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncRepository extends Mock implements SyncRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSyncRepository mockRepository;
  late SyncBloc syncBloc;

  final testItem = SyncItem(
    id: 'sync-item-101',
    endpoint: '/api/v1/mobile/quotes',
    httpMethod: 'POST',
    payloadJson: '{"amount": 12500}',
    status: SyncItemStatus.QUEUED,
    createdAt: DateTime.parse('2026-11-09T00:00:00Z'),
    idempotencyKey: 'idem-key-101',
  );

  setUpAll(() {
    registerFallbackValue(testItem);
  });

  setUp(() {
    mockRepository = MockSyncRepository();
    syncBloc = SyncBloc(syncRepository: mockRepository);
  });

  tearDown(() {
    syncBloc.close();
  });

  group('Phase 28 — SyncBloc Unit & State Machine Tests', () {
    test('initial state is SyncInitial with 0 pending count', () {
      expect(syncBloc.state, equals(const SyncInitial()));
      expect(syncBloc.state.pendingCount, 0);
    });

    blocTest<SyncBloc, SyncState>(
      'subscribes to pending count stream on SyncWatchStarted and emits SyncIdle',
      build: () {
        when(() => mockRepository.watchPendingCount()).thenAnswer((_) => Stream.value(5));
        return syncBloc;
      },
      act: (bloc) => bloc.add(SyncWatchStarted()),
      expect: () => [
        const SyncIdle(5),
      ],
      verify: (_) {
        verify(() => mockRepository.watchPendingCount()).called(1);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'emits SyncIdle with updated count on SyncPendingCountUpdated',
      build: () => syncBloc,
      seed: () => const SyncIdle(2),
      act: (bloc) => bloc.add(const SyncPendingCountUpdated(4)),
      expect: () => [
        const SyncIdle(4),
      ],
    );

    blocTest<SyncBloc, SyncState>(
      'enqueues request item and emits SyncIdle with new count on EnqueueSyncItem',
      build: () {
        when(() => mockRepository.enqueueRequest(any())).thenAnswer((_) async {});
        when(() => mockRepository.getPendingCount()).thenAnswer((_) async => 3);
        return syncBloc;
      },
      seed: () => const SyncIdle(2),
      act: (bloc) => bloc.add(EnqueueSyncItem(testItem)),
      expect: () => [
        const SyncIdle(3),
      ],
      verify: (_) {
        verify(() => mockRepository.enqueueRequest(testItem)).called(1);
        verify(() => mockRepository.getPendingCount()).called(1);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'drains queue and emits [SyncRunning, SyncIdle] on SyncConnectivityRestored',
      build: () {
        when(() => mockRepository.processSyncQueue()).thenAnswer((_) async {});
        when(() => mockRepository.getPendingCount()).thenAnswer((_) async => 0);
        return syncBloc;
      },
      seed: () => const SyncIdle(4),
      act: (bloc) => bloc.add(SyncConnectivityRestored()),
      expect: () => [
        const SyncRunning(4),
        const SyncIdle(0),
      ],
      verify: (_) {
        verify(() => mockRepository.processSyncQueue()).called(1);
        verify(() => mockRepository.getPendingCount()).called(1);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'manually flushes queue on SyncTriggered and emits [SyncRunning, SyncIdle]',
      build: () {
        when(() => mockRepository.syncAllPending()).thenAnswer((_) async {});
        when(() => mockRepository.getPendingCount()).thenAnswer((_) async => 0);
        return syncBloc;
      },
      seed: () => const SyncIdle(3),
      act: (bloc) => bloc.add(SyncTriggered()),
      expect: () => [
        const SyncRunning(3),
        const SyncIdle(0),
      ],
      verify: (_) {
        verify(() => mockRepository.syncAllPending()).called(1);
        verify(() => mockRepository.getPendingCount()).called(1);
      },
    );

    test('cancels watch stream subscription cleanly on close', () async {
      final controller = StreamController<int>();
      when(() => mockRepository.watchPendingCount()).thenAnswer((_) => controller.stream);

      syncBloc.add(SyncWatchStarted());
      await Future.delayed(const Duration(milliseconds: 20));
      expect(controller.hasListener, isTrue);

      await syncBloc.close();
      expect(controller.hasListener, isFalse);
      await controller.close();
    });
  });
}
