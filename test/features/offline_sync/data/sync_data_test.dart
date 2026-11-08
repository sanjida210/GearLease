import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/network/api_client.dart';
import 'package:gearlease/core/network/network_info.dart';
import 'package:gearlease/core/storage/database_helper.dart';
import 'package:gearlease/features/offline_sync/data/datasources/sync_local_datasource.dart';
import 'package:gearlease/features/offline_sync/data/repositories/sync_repository_impl.dart';
import 'package:gearlease/features/offline_sync/domain/entities/sync_item.dart';
import 'package:mocktail/mocktail.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}
class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}
class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabaseHelper mockDatabaseHelper;
  late MockApiClient mockApiClient;
  late MockDio mockDio;
  late MockNetworkInfo mockNetworkInfo;
  late SyncLocalDataSourceImpl localDataSource;
  late SyncRepositoryImpl repository;

  final testItem = SyncItem(
    id: 'sync-001',
    idempotencyKey: 'idem-001',
    actionType: '/api/v1/mobile/quotes',
    payloadJson: '{"amount": 5000}',
    status: SyncStatus.pending,
    createdAt: DateTime.parse('2026-11-04T12:00:00Z'),
  );

  setUp(() {
    mockDatabaseHelper = MockDatabaseHelper();
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    mockNetworkInfo = MockNetworkInfo();

    when(() => mockApiClient.dio).thenReturn(mockDio);

    localDataSource = SyncLocalDataSourceImpl(databaseHelper: mockDatabaseHelper);

    when(() => mockDatabaseHelper.getPendingSyncQueueItems()).thenAnswer((_) async => []);

    repository = SyncRepositoryImpl(
      localDataSource: localDataSource,
      apiClient: mockApiClient,
      networkInfo: mockNetworkInfo,
    );
  });

  group('SyncLocalDataSourceImpl Tests', () {
    test('enqueueItem inserts into databaseHelper sync_queue', () async {
      when(() => mockDatabaseHelper.insertSyncQueueItem(any())).thenAnswer((_) async => 1);

      await localDataSource.enqueueItem(testItem);

      verify(() => mockDatabaseHelper.insertSyncQueueItem(any())).called(1);
    });

    test('getPendingItems returns mapped SyncItems', () async {
      when(() => mockDatabaseHelper.getPendingSyncQueueItems()).thenAnswer((_) async => [
        {
          'id': 'sync-001',
          'idempotency_key': 'idem-001',
          'endpoint': '/api/v1/mobile/quotes',
          'payload': '{"amount": 5000}',
          'status': 'PENDING',
          'created_at': 1762257600000,
        }
      ]);

      final items = await localDataSource.getPendingItems();

      expect(items.length, 1);
      expect(items.first.id, 'sync-001');
      expect(items.first.status, SyncStatus.pending);
    });

    test('updateItemStatus updates status in databaseHelper', () async {
      when(() => mockDatabaseHelper.updateSyncItemStatus('sync-001', 'SYNCED')).thenAnswer((_) async => 1);

      await localDataSource.updateItemStatus('sync-001', SyncStatus.synced);

      verify(() => mockDatabaseHelper.updateSyncItemStatus('sync-001', 'SYNCED')).called(1);
    });
  });

  group('SyncRepositoryImpl Tests', () {
    test('syncAllPending processes pending items and marks synced upon 200 response', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDatabaseHelper.getPendingSyncQueueItems()).thenAnswer((_) async => [
        {
          'id': 'sync-001',
          'idempotency_key': 'idem-001',
          'endpoint': '/api/v1/mobile/quotes',
          'payload': '{"amount": 5000}',
          'status': 'PENDING',
          'created_at': 1762257600000,
        }
      ]);
      when(() => mockDatabaseHelper.updateSyncItemStatus(any(), any())).thenAnswer((_) async => 1);
      when(() => mockDio.post(any(), data: any(named: 'data'), options: any(named: 'options'))).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await repository.syncAllPending();

      verify(() => mockDio.post(
        '/api/v1/mobile/quotes',
        data: any(named: 'data'),
        options: any(named: 'options'),
      )).called(1);
      verify(() => mockDatabaseHelper.updateSyncItemStatus('sync-001', 'SYNCED')).called(1);
    });

    test('syncAllPending does nothing when offline', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      await repository.syncAllPending();

      verifyNever(() => mockDio.post(any(), data: any(named: 'data'), options: any(named: 'options')));
    });
  });
}
