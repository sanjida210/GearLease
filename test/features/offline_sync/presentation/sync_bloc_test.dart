import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
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

  setUp(() {
    mockRepository = MockSyncRepository();
    syncBloc = SyncBloc(syncRepository: mockRepository);
  });

  tearDown(() {
    syncBloc.close();
  });

  group('SyncBloc Tests', () {
    test('initial state is SyncInitial with 0 pending count', () {
      expect(syncBloc.state, equals(const SyncInitial()));
      expect(syncBloc.state.pendingCount, 0);
    });

    blocTest<SyncBloc, SyncState>(
      'subscribes to pending count stream on SyncWatchStarted',
      build: () {
        when(() => mockRepository.watchPendingCount()).thenAnswer((_) => Stream.value(3));
        return syncBloc;
      },
      act: (bloc) => bloc.add(SyncWatchStarted()),
      expect: () => [
        const SyncIdle(3),
      ],
    );

    blocTest<SyncBloc, SyncState>(
      'emits [SyncRunning, SyncIdle] on SyncTriggered',
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
    );
  });
}
