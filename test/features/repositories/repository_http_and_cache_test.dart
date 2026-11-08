import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/error/failures.dart';
import 'package:gearlease/core/network/api_client.dart';
import 'package:gearlease/core/network/network_info.dart';
import 'package:gearlease/core/storage/database_helper.dart';
import 'package:gearlease/features/offline_sync/data/datasources/sync_local_datasource.dart';
import 'package:gearlease/features/offline_sync/data/repositories/sync_repository_impl.dart';
import 'package:gearlease/features/quote/data/datasources/quote_local_datasource.dart';
import 'package:gearlease/features/quote/data/datasources/quote_remote_datasource.dart';
import 'package:gearlease/features/quote/data/repositories/quote_repository_impl.dart';
import 'package:gearlease/features/quote/domain/entities/quote_calculation.dart';
import 'package:gearlease/features/telemetry/data/datasources/telemetry_ws_datasource.dart';
import 'package:gearlease/features/telemetry/data/models/machine_telemetry_model.dart';
import 'package:gearlease/features/telemetry/data/repositories/telemetry_repository_impl.dart';
import 'package:gearlease/features/telemetry/domain/entities/machine_telemetry.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockTelemetryWsDataSource extends Mock implements TelemetryWsDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDio mockDio;
  late MockApiClient mockApiClient;
  late MockDatabaseHelper mockDatabaseHelper;
  late MockNetworkInfo mockNetworkInfo;
  late MockTelemetryWsDataSource mockWsDataSource;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = MockDio();
    mockApiClient = MockApiClient();
    when(() => mockApiClient.dio).thenReturn(mockDio);

    mockDatabaseHelper = MockDatabaseHelper();
    mockNetworkInfo = MockNetworkInfo();
    mockWsDataSource = MockTelemetryWsDataSource();
  });

  group('Phase 28 — QuoteRepositoryImpl HTTP & SQLite Fallback Tests', () {
    late QuoteRemoteDataSource remoteDataSource;
    late QuoteLocalDataSource localDataSource;
    late QuoteRepositoryImpl quoteRepository;

    final sampleAssetJson = {
      'id': 'ast-cat-01',
      'vendor_id': 'vnd-101',
      'serial_number': 'CAT-320D-2026',
      'barcode_payload': 'CAT-320D-2026',
      'barcode_symbology': 'CODE_128',
      'make': 'Caterpillar',
      'model': '320D Excavator',
      'category': 'Heavy Earthmoving',
      'initial_value_cents': 24500000,
      'iot_device_identifier': 'IOT-CAT-01',
      'current_condition_rating': 'GRADE_A',
    };

    final sampleCachedDbRow = {
      'id': 'ast-cat-01',
      'serial_number': 'CAT-320D-2026',
      'make': 'Caterpillar',
      'model': '320D Excavator',
      'msrp_cents': 24500000,
      'category': 'Heavy Earthmoving',
      'payload_json':
          '{"id":"ast-cat-01","vendor_id":"vnd-101","serial_number":"CAT-320D-2026","barcode_payload":"CAT-320D-2026","barcode_symbology":"CODE_128","make":"Caterpillar","model":"320D Excavator","category":"Heavy Earthmoving","initial_value_cents":24500000,"iot_device_identifier":"IOT-CAT-01","current_condition_rating":"GRADE_A"}',
    };

    setUp(() {
      remoteDataSource = QuoteRemoteDataSourceImpl(apiClient: mockApiClient);
      localDataSource = QuoteLocalDataSourceImpl(databaseHelper: mockDatabaseHelper);
      quoteRepository = QuoteRepositoryImpl(
        remoteDataSource: remoteDataSource,
        localDataSource: localDataSource,
        networkInfo: mockNetworkInfo,
      );
    });

    test('200 Response: fetches remote asset, saves to SQLite cache, and returns success Result', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDio.get(
            '/api/v1/assets/lookup',
            queryParameters: {'code': 'CAT-320D-2026'},
          )).thenAnswer((_) async => Response(
            statusCode: 200,
            data: sampleAssetJson,
            requestOptions: RequestOptions(path: '/api/v1/assets/lookup'),
          ));
      when(() => mockDatabaseHelper.upsertOfflineAsset(any())).thenAnswer((_) async => 1);

      final result = await quoteRepository.getAssetByBarcode('CAT-320D-2026');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.serialNumber, 'CAT-320D-2026');
      expect(result.dataOrNull?.make, 'Caterpillar');
      verify(() => mockDatabaseHelper.upsertOfflineAsset(any())).called(1);
    });

    test('Network Exception: catches DioException and seamlessly falls back to SQLite cache', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/assets/lookup'),
          error: 'Connection timeout (no route to host)',
          type: DioExceptionType.connectionTimeout,
        ),
      );
      when(() => mockDatabaseHelper.getOfflineAssetByBarcode('CAT-320D-2026'))
          .thenAnswer((_) async => sampleCachedDbRow);

      final result = await quoteRepository.getAssetByBarcode('CAT-320D-2026');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.serialNumber, 'CAT-320D-2026');
      expect(result.dataOrNull?.model, '320D Excavator');
      verify(() => mockDatabaseHelper.getOfflineAssetByBarcode('CAT-320D-2026')).called(1);
    });

    test('Offline Mode with empty cache: returns NetworkFailure when disconnected and not in cache', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);
      when(() => mockDatabaseHelper.getOfflineAssetByBarcode('CAT-320D-2026'))
          .thenAnswer((_) async => null);

      final result = await quoteRepository.getAssetByBarcode('CAT-320D-2026');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(result.failureOrNull?.message, contains('offline'));
    });

    test('Quote Calculation: 200 Response returns calculated quote model', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDio.post(
            '/api/v1/mobile/quotes/quick-calculate',
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            statusCode: 200,
            data: {
              'quote_id': 'qte_remote_2026',
              'qualification_status': 'INSTANT_QUALIFIED',
              'repayment_type': 'FIXED_MONTHLY',
              'term_months': 36,
              'requested_amount_cents': 24500000,
              'fixed_monthly_cents': 754000,
              'revenue_share_pct': 3.5,
              'estimated_monthly_cents': 754000,
              'floor_cents': 500000,
              'cap_cents': 1100000,
              'expires_in_seconds': 900,
            },
            requestOptions: RequestOptions(path: '/api/v1/mobile/quotes/quick-calculate'),
          ));

      final result = await quoteRepository.calculateQuickQuote(
        barcode: 'CAT-320D-2026',
        vendorOrgId: 'vnd-101',
        invoiceAmountCents: 24500000,
        requestedTermMonths: 36,
        repaymentType: RepaymentStructureType.FIXED_MONTHLY,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.quoteId, 'qte_remote_2026');
      expect(result.dataOrNull?.isOfflineEstimate, isFalse);
    });

    test('Quote Calculation: Network Exception falls back to SQLite cached asset with OFFLINE_ESTIMATE flag', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/mobile/quotes/quick-calculate'),
          error: '503 Service Unavailable',
          type: DioExceptionType.badResponse,
        ),
      );
      when(() => mockDatabaseHelper.getOfflineAssetByBarcode('CAT-320D-2026'))
          .thenAnswer((_) async => sampleCachedDbRow);

      final result = await quoteRepository.calculateQuickQuote(
        barcode: 'CAT-320D-2026',
        vendorOrgId: 'vnd-101',
        invoiceAmountCents: 24500000,
        requestedTermMonths: 36,
        repaymentType: RepaymentStructureType.FIXED_MONTHLY,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.isOfflineEstimate, isTrue);
      expect(result.dataOrNull?.estimateFlag, 'OFFLINE_ESTIMATE');
      expect(result.dataOrNull?.fixedMonthlyCents, greaterThan(0));
    });
  });

  group('Phase 28 — TelemetryRepositoryImpl HTTP & SQLite Fallback Tests', () {
    late TelemetryRepositoryImpl telemetryRepository;

    final testModel = MachineTelemetryModel(
      assetId: 'ast-cat-01',
      machineName: 'CAT 320D Excavator',
      category: 'Heavy Earthmoving',
      runningHours: 1250.0,
      temperatureCelsius: 82.0,
      motorRpm: 1950.0,
      status: MachineStatus.warning,
      currentBillingCents: 150000,
      billingType: 'Revenue-Indexed',
      timestamp: DateTime.parse('2026-11-09T00:00:00Z'),
    );

    setUp(() {
      telemetryRepository = TelemetryRepositoryImpl(
        wsDataSource: mockWsDataSource,
        databaseHelper: mockDatabaseHelper,
        apiClient: mockApiClient,
        networkInfo: mockNetworkInfo,
      );
    });

    test('200 Response: scheduleWarrantyService posts to server online', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDio.post(
            '/api/v1/telemetry/assets/ast-cat-01/service-request',
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/v1/telemetry/assets/ast-cat-01/service-request'),
          ));

      final success = await telemetryRepository.scheduleWarrantyService('ast-cat-01', 'Thermal calibration needed');

      expect(success, isTrue);
      verify(() => mockDio.post(
            '/api/v1/telemetry/assets/ast-cat-01/service-request',
            data: any(named: 'data'),
          )).called(1);
    });

    test('Network Exception: scheduleWarrantyService queues request into SQLite sync_queue when offline', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);
      when(() => mockDatabaseHelper.insertSyncQueueItem(any())).thenAnswer((_) async => 1);

      final success = await telemetryRepository.scheduleWarrantyService('ast-cat-01', 'Offline booking request');

      expect(success, isTrue);
      verify(() => mockDatabaseHelper.insertSyncQueueItem(any())).called(1);
    });

    test('Cache Fallback: watchMachineTelemetry yields SQLite cached telemetry before streaming live updates', () async {
      when(() => mockDatabaseHelper.getTelemetry('ast-cat-01'))
          .thenAnswer((_) async => testModel.toDbMap());
      when(() => mockDatabaseHelper.upsertTelemetry(any())).thenAnswer((_) async => 1);
      when(() => mockWsDataSource.streamMachineTelemetry('ast-cat-01'))
          .thenAnswer((_) => Stream.value(testModel));

      final streamList = await telemetryRepository.watchMachineTelemetry('ast-cat-01').take(2).toList();

      expect(streamList.length, 2);
      expect(streamList.first.assetId, 'ast-cat-01');
      expect(streamList.first.temperatureCelsius, 82.0);
    });
  });

  group('Phase 28 — SyncRepositoryImpl HTTP Drain & SQLite SyncQueue Tests', () {
    late SyncLocalDataSourceImpl localDataSource;
    late SyncRepositoryImpl syncRepository;
    late StreamController<bool> connectivityController;

    setUp(() {
      connectivityController = StreamController<bool>.broadcast();
      when(() => mockNetworkInfo.onConnectivityChanged).thenAnswer((_) => connectivityController.stream);
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDatabaseHelper.getPendingSyncQueueItems()).thenAnswer((_) async => []);

      localDataSource = SyncLocalDataSourceImpl(databaseHelper: mockDatabaseHelper);
      syncRepository = SyncRepositoryImpl(
        localDataSource: localDataSource,
        apiClient: mockApiClient,
        networkInfo: mockNetworkInfo,
      );
    });

    tearDown(() {
      syncRepository.dispose();
      connectivityController.close();
    });

    test('200 Response: drains queue item, sends Idempotency-Key header, and updates SQLite status to SYNCED', () async {
      when(() => mockDatabaseHelper.getPendingSyncQueueItems()).thenAnswer((_) async => [
        {
          'id': 'sync-batch-01',
          'idempotency_key': 'idem-uuid-999',
          'endpoint': '/api/v1/leases/sign',
          'method': 'POST',
          'payload': '{"lease_id":"ls_123"}',
          'status': 'QUEUED',
          'retry_count': 0,
          'created_at': 1762257600000,
        }
      ]);
      when(() => mockDatabaseHelper.updateSyncItemStatus(any(), any(),
              retryCount: any(named: 'retryCount'), errorMessage: any(named: 'errorMessage')))
          .thenAnswer((_) async => 1);
      when(() => mockDio.post(any(), data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => Response(
                statusCode: 200,
                requestOptions: RequestOptions(path: '/api/v1/leases/sign'),
              ));

      await syncRepository.processSyncQueue();

      final captured = verify(() => mockDio.post(
            '/api/v1/leases/sign',
            data: any(named: 'data'),
            options: captureAny(named: 'options'),
          )).captured;

      final options = captured.first as Options;
      expect(options.headers?['Idempotency-Key'], 'idem-uuid-999');
      verify(() => mockDatabaseHelper.updateSyncItemStatus('sync-batch-01', 'SYNCED')).called(1);
    });

    test('Network Exception: increments retryCount and retains item in SQLite for next retry', () async {
      when(() => mockDatabaseHelper.getPendingSyncQueueItems()).thenAnswer((_) async => [
        {
          'id': 'sync-retry-01',
          'idempotency_key': 'idem-retry-01',
          'endpoint': '/api/v1/leases/sign',
          'method': 'POST',
          'payload': '{"lease_id":"ls_456"}',
          'status': 'QUEUED',
          'retry_count': 1,
          'created_at': 1762257600000,
        }
      ]);
      when(() => mockDatabaseHelper.updateSyncItemStatus(any(), any(),
              retryCount: any(named: 'retryCount'), errorMessage: any(named: 'errorMessage')))
          .thenAnswer((_) async => 1);
      when(() => mockDio.post(any(), data: any(named: 'data'), options: any(named: 'options'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/leases/sign'),
          error: 'Connection dropped',
          type: DioExceptionType.connectionError,
        ),
      );

      await syncRepository.processSyncQueue();

      verify(() => mockDatabaseHelper.updateSyncItemStatus(
            'sync-retry-01',
            'QUEUED',
            retryCount: 2,
            errorMessage: any(named: 'errorMessage'),
          )).called(1);
    });

    test('409 Conflict: marks SQLite item as CONFLICT_REJECTED and emits conflict alert', () async {
      when(() => mockDatabaseHelper.getPendingSyncQueueItems()).thenAnswer((_) async => [
        {
          'id': 'sync-conflict-02',
          'idempotency_key': 'idem-conflict-02',
          'endpoint': '/api/v1/leases/sign',
          'method': 'POST',
          'payload': '{"asset_id":"ast_conflict"}',
          'status': 'QUEUED',
          'retry_count': 0,
          'created_at': 1762257600000,
        }
      ]);
      when(() => mockDatabaseHelper.updateSyncItemStatus(any(), any(),
              retryCount: any(named: 'retryCount'), errorMessage: any(named: 'errorMessage')))
          .thenAnswer((_) async => 1);
      when(() => mockDio.post(any(), data: any(named: 'data'), options: any(named: 'options'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/leases/sign'),
          response: Response(
            statusCode: 409,
            data: {'error': 'Asset already leased by another tenant'},
            requestOptions: RequestOptions(path: '/api/v1/leases/sign'),
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      final alertFuture = expectLater(
        syncRepository.conflictAlertStream,
        emits(isA<SyncConflictAlert>()
            .having((a) => a.itemId, 'itemId', 'sync-conflict-02')
            .having((a) => a.message, 'message', contains('409 Conflict'))),
      );

      await syncRepository.processSyncQueue();
      await alertFuture;

      verify(() => mockDatabaseHelper.updateSyncItemStatus(
            'sync-conflict-02',
            'CONFLICT_REJECTED',
            errorMessage: any(named: 'errorMessage'),
          )).called(1);
    });
  });
}
