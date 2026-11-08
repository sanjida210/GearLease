import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/network/api_client.dart';
import 'package:gearlease/core/network/network_info.dart';
import 'package:gearlease/core/storage/database_helper.dart';
import 'package:gearlease/features/offline_sync/data/datasources/sync_local_datasource.dart';
import 'package:gearlease/features/offline_sync/data/repositories/sync_repository_impl.dart';
import 'package:gearlease/features/offline_sync/data/workers/background_sync_worker.dart';
import 'package:gearlease/features/offline_sync/domain/entities/sync_item.dart';
import 'package:mocktail/mocktail.dart';
import 'package:workmanager/workmanager.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}
class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}
class MockNetworkInfo extends Mock implements NetworkInfo {}
class MockWorkmanager extends Mock implements Workmanager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabaseHelper mockDatabaseHelper;
  late MockApiClient mockApiClient;
  late MockDio mockDio;
  late MockNetworkInfo mockNetworkInfo;
  late StreamController<bool> connectivityController;
  late SyncLocalDataSourceImpl localDataSource;
  late SyncRepositoryImpl repository;

  final testItem = SyncItem(
    id: 'sync-001',
    endpoint: '/api/v1/mobile/quotes',
    httpMethod: 'POST',
    payloadJson: '{"amount": 5000}',
    status: SyncItemStatus.QUEUED,
    createdAt: DateTime.parse('2026-11-04T12:00:00Z'),
    idempotencyKey: 'idem-001',
  );

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDatabaseHelper = MockDatabaseHelper();
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    mockNetworkInfo = MockNetworkInfo();
    connectivityController = StreamController<bool>.broadcast();

    when(() => mockApiClient.dio).thenReturn(mockDio);
    when(() => mockNetworkInfo.onConnectivityChanged).thenAnswer((_) => connectivityController.stream);
    when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);

    localDataSource = SyncLocalDataSourceImpl(databaseHelper: mockDatabaseHelper);

    when(() => mockDatabaseHelper.getPendingSyncQueueItems()).thenAnswer((_) async => []);

    repository = SyncRepositoryImpl(
      localDataSource: localDataSource,
      apiClient: mockApiClient,
      networkInfo: mockNetworkInfo,
    );
  });

  tearDown(() {
    repository.dispose();
    connectivityController.close();
  });

  group('SyncLocalDataSourceImpl CRUD Tests', () {
    test('Create: enqueueItem inserts item into sync_queue table', () async {
      when(() => mockDatabaseHelper.insertSyncQueueItem(any())).thenAnswer((_) async => 1);

      await localDataSource.enqueueItem(testItem);

      verify(() => mockDatabaseHelper.insertSyncQueueItem(any(that: isA<Map<String, dynamic>>()))).called(1);
    });

    test('Read: getPendingItems returns mapped SyncItems', () async {
      when(() => mockDatabaseHelper.getPendingSyncQueueItems()).thenAnswer((_) async => [
        {
          'id': 'sync-001',
          'idempotency_key': 'idem-001',
          'endpoint': '/api/v1/mobile/quotes',
          'method': 'POST',
          'payload': '{"amount": 5000}',
          'status': 'QUEUED',
          'retry_count': 0,
          'created_at': 1762257600000,
        }
      ]);

      final items = await localDataSource.getPendingItems();

      expect(items.length, 1);
      expect(items.first.id, 'sync-001');
      expect(items.first.status, SyncItemStatus.QUEUED);
    });

    test('Read: getItemById returns specific item by id', () async {
      when(() => mockDatabaseHelper.getSyncQueueItemById('sync-001')).thenAnswer((_) async => {
        'id': 'sync-001',
        'idempotency_key': 'idem-001',
        'endpoint': '/api/v1/mobile/quotes',
        'method': 'POST',
        'payload': '{"amount": 5000}',
        'status': 'QUEUED',
        'retry_count': 0,
        'created_at': 1762257600000,
      });

      final item = await localDataSource.getItemById('sync-001');

      expect(item, isNotNull);
      expect(item?.id, equals('sync-001'));
      expect(item?.endpoint, equals('/api/v1/mobile/quotes'));
    });

    test('Read: getAllItems returns all rows in table', () async {
      when(() => mockDatabaseHelper.getAllSyncQueueItems()).thenAnswer((_) async => [
        {
          'id': 'sync-001',
          'idempotency_key': 'idem-001',
          'endpoint': '/api/v1/mobile/quotes',
          'method': 'POST',
          'payload': '{"amount": 5000}',
          'status': 'SYNCED',
          'retry_count': 0,
          'created_at': 1762257600000,
        }
      ]);

      final items = await localDataSource.getAllItems();
      expect(items.length, equals(1));
      expect(items.first.status, equals(SyncItemStatus.SYNCED));
    });

    test('Update: updateItemStatus updates status and error in databaseHelper', () async {
      when(() => mockDatabaseHelper.updateSyncItemStatus(
            'sync-001',
            'SYNCED',
            retryCount: any(named: 'retryCount'),
            errorMessage: any(named: 'errorMessage'),
          )).thenAnswer((_) async => 1);

      await localDataSource.updateItemStatus('sync-001', SyncItemStatus.SYNCED);

      verify(() => mockDatabaseHelper.updateSyncItemStatus('sync-001', 'SYNCED')).called(1);
    });

    test('Delete: deleteItem removes item from table', () async {
      when(() => mockDatabaseHelper.deleteSyncQueueItem('sync-001')).thenAnswer((_) async => 1);

      await localDataSource.deleteItem('sync-001');

      verify(() => mockDatabaseHelper.deleteSyncQueueItem('sync-001')).called(1);
    });

    test('Delete: clearCompleted removes all SYNCED items', () async {
      when(() => mockDatabaseHelper.clearCompletedSyncItems()).thenAnswer((_) async => 2);

      await localDataSource.clearCompleted();

      verify(() => mockDatabaseHelper.clearCompletedSyncItems()).called(1);
    });
  });

  group('SyncRepositoryImpl Connectivity Trigger & FIFO Queue Drainer Tests', () {
    test('automatically triggers FIFO processSyncQueue when connectivity is restored', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDatabaseHelper.getPendingSyncQueueItems()).thenAnswer((_) async => [
        {
          'id': 'sync-fifo-01',
          'idempotency_key': 'idem-fifo-01',
          'endpoint': '/api/v1/mobile/quotes',
          'method': 'POST',
          'payload': '{"amount": 1000}',
          'status': 'QUEUED',
          'retry_count': 0,
          'created_at': 1762257600000,
        }
      ]);
      when(() => mockDatabaseHelper.updateSyncItemStatus(any(), any(), retryCount: any(named: 'retryCount'), errorMessage: any(named: 'errorMessage'))).thenAnswer((_) async => 1);
      when(() => mockDio.post(any(), data: any(named: 'data'), options: any(named: 'options'))).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      // Simulate network coming back online
      connectivityController.add(true);
      await pumpEventQueue();

      verify(() => mockDio.post(
        '/api/v1/mobile/quotes',
        data: any(named: 'data'),
        options: any(named: 'options'),
      )).called(1);
      verify(() => mockDatabaseHelper.updateSyncItemStatus('sync-fifo-01', 'SYNCED')).called(1);
    });

    test('attaches Idempotency-Key header on every HTTP request', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDatabaseHelper.getPendingSyncQueueItems()).thenAnswer((_) async => [
        {
          'id': 'sync-idem-01',
          'idempotency_key': 'test-uuid-idem-key',
          'endpoint': '/api/v1/leases/sign',
          'method': 'POST',
          'payload': '{"lease_id":"ls_1"}',
          'status': 'QUEUED',
          'retry_count': 0,
          'created_at': 1762257600000,
        }
      ]);
      when(() => mockDatabaseHelper.updateSyncItemStatus(any(), any(), retryCount: any(named: 'retryCount'), errorMessage: any(named: 'errorMessage'))).thenAnswer((_) async => 1);
      when(() => mockDio.post(any(), data: any(named: 'data'), options: any(named: 'options'))).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await repository.processSyncQueue();

      final captured = verify(() => mockDio.post(
        '/api/v1/leases/sign',
        data: any(named: 'data'),
        options: captureAny(named: 'options'),
      )).captured;

      final options = captured.first as Options;
      expect(options.headers?['Idempotency-Key'], equals('test-uuid-idem-key'));
    });
  });

  group('SyncRepositoryImpl Multipart Upload for GearRelay Inspection Bundles Tests', () {
    test('sends FormData multipart when item contains mediaFilePaths or inspection bundle', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDatabaseHelper.getPendingSyncQueueItems()).thenAnswer((_) async => [
        {
          'id': 'sync-bundle-01',
          'idempotency_key': 'idem-bundle-01',
          'endpoint': '/api/v1/mobile/assets/inspection-bundle',
          'method': 'POST',
          'payload': '{"asset_id":"ast_123","_media_file_paths":["/tmp/angle1.jpg","/tmp/angle2.jpg"]}',
          'status': 'QUEUED',
          'retry_count': 0,
          'created_at': 1762257600000,
        }
      ]);
      when(() => mockDatabaseHelper.updateSyncItemStatus(any(), any(), retryCount: any(named: 'retryCount'), errorMessage: any(named: 'errorMessage'))).thenAnswer((_) async => 1);
      when(() => mockDio.post(any(), data: any(named: 'data'), options: any(named: 'options'))).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await repository.processSyncQueue();

      final captured = verify(() => mockDio.post(
        '/api/v1/mobile/assets/inspection-bundle',
        data: captureAny(named: 'data'),
        options: any(named: 'options'),
      )).captured;

      expect(captured.first, isA<FormData>());
      final formData = captured.first as FormData;
      expect(formData.fields.any((f) => f.key == 'asset_id' && f.value == 'ast_123'), isTrue);
    });
  });

  group('SyncRepositoryImpl 409 Conflict Handling Tests', () {
    test('handles 409 Conflict by marking CONFLICT_REJECTED and emitting alert', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDatabaseHelper.getPendingSyncQueueItems()).thenAnswer((_) async => [
        {
          'id': 'sync-conflict-01',
          'idempotency_key': 'idem-conflict-01',
          'endpoint': '/api/v1/leases/sign',
          'method': 'POST',
          'payload': '{"asset_id":"ast_already_leased"}',
          'status': 'QUEUED',
          'retry_count': 0,
          'created_at': 1762257600000,
        }
      ]);
      when(() => mockDatabaseHelper.updateSyncItemStatus(any(), any(), retryCount: any(named: 'retryCount'), errorMessage: any(named: 'errorMessage'))).thenAnswer((_) async => 1);

      when(() => mockDio.post(any(), data: any(named: 'data'), options: any(named: 'options'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/leases/sign'),
          response: Response(
            statusCode: 409,
            data: {'error': 'Asset ast_already_leased is already under an active lease'},
            requestOptions: RequestOptions(path: '/api/v1/leases/sign'),
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      final alertFuture = expectLater(
        repository.conflictAlertStream,
        emits(isA<SyncConflictAlert>()
            .having((a) => a.itemId, 'itemId', 'sync-conflict-01')
            .having((a) => a.endpoint, 'endpoint', '/api/v1/leases/sign')
            .having((a) => a.message, 'message', contains('409 Conflict'))),
      );

      await repository.processSyncQueue();
      await alertFuture;

      verify(() => mockDatabaseHelper.updateSyncItemStatus(
            'sync-conflict-01',
            'CONFLICT_REJECTED',
            errorMessage: any(named: 'errorMessage'),
          )).called(1);
    });
  });

  group('BackgroundSyncWorker Workmanager Configuration Tests', () {
    test('schedules periodic background sync and registers callback dispatcher', () async {
      final mockWorkmanager = MockWorkmanager();
      when(() => mockWorkmanager.initialize(any(), isInDebugMode: any(named: 'isInDebugMode'))).thenAnswer((_) async {});
      when(() => mockWorkmanager.registerPeriodicTask(
            any(),
            any(),
            frequency: any(named: 'frequency'),
            constraints: any(named: 'constraints'),
            tag: any(named: 'tag'),
            existingWorkPolicy: any(named: 'existingWorkPolicy'),
          )).thenAnswer((_) async {});
      when(() => mockWorkmanager.cancelAll()).thenAnswer((_) async {});

      final worker = BackgroundSyncWorker(workmanager: mockWorkmanager);

      await worker.initialize(isInDebugMode: false, forcePlatformSupport: true);
      verify(() => mockWorkmanager.initialize(any(), isInDebugMode: false)).called(1);

      await worker.registerPeriodicSync(forcePlatformSupport: true);
      verify(() => mockWorkmanager.registerPeriodicTask(
            backgroundSyncTaskKey,
            backgroundSyncTaskKey,
            frequency: any(named: 'frequency'),
            constraints: any(named: 'constraints'),
            tag: any(named: 'tag'),
            existingWorkPolicy: any(named: 'existingWorkPolicy'),
          )).called(1);

      await worker.cancelAll();
      verify(() => mockWorkmanager.cancelAll()).called(1);
    });
  });
}
