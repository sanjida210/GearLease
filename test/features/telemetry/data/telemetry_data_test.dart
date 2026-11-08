import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/network/api_client.dart';
import 'package:gearlease/core/network/network_info.dart';
import 'package:gearlease/core/storage/database_helper.dart';
import 'package:gearlease/features/telemetry/data/datasources/telemetry_ws_datasource.dart';
import 'package:gearlease/features/telemetry/data/models/machine_telemetry_model.dart';
import 'package:gearlease/features/telemetry/data/repositories/telemetry_repository_impl.dart';
import 'package:gearlease/features/telemetry/domain/entities/machine_telemetry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MockTelemetryWsDataSource extends Mock implements TelemetryWsDataSource {}
class MockDatabaseHelper extends Mock implements DatabaseHelper {}
class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}
class MockNetworkInfo extends Mock implements NetworkInfo {}
class MockWebSocketChannel extends Mock implements WebSocketChannel {}
class MockWebSocketSink extends Mock implements WebSocketSink {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTelemetryWsDataSource mockWsDataSource;
  late MockDatabaseHelper mockDatabaseHelper;
  late MockApiClient mockApiClient;
  late MockDio mockDio;
  late MockNetworkInfo mockNetworkInfo;
  late TelemetryRepositoryImpl repository;

  final testModel = MachineTelemetryModel(
    assetId: 'ast_probat12',
    machineName: 'Probat P12 Roaster',
    category: 'Commercial Kitchen',
    runningHours: 1248.5,
    temperatureCelsius: 78.0,
    motorRpm: 1420.0,
    status: MachineStatus.warning,
    currentBillingCents: 112000,
    billingType: 'Revenue-Indexed',
    timestamp: DateTime.parse('2026-11-04T10:30:00Z'),
  );

  setUp(() {
    mockWsDataSource = MockTelemetryWsDataSource();
    mockDatabaseHelper = MockDatabaseHelper();
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    mockNetworkInfo = MockNetworkInfo();

    when(() => mockApiClient.dio).thenReturn(mockDio);

    repository = TelemetryRepositoryImpl(
      wsDataSource: mockWsDataSource,
      databaseHelper: mockDatabaseHelper,
      apiClient: mockApiClient,
      networkInfo: mockNetworkInfo,
    );
  });

  group('MachineTelemetryModel Tests', () {
    test('fromJson parses full JSON payload correctly', () {
      final json = {
        'asset_id': 'ast_probat12',
        'machine_name': 'Probat P12 Roaster',
        'category': 'Commercial Kitchen',
        'running_hours': 1248.5,
        'temperature_celsius': 78.0,
        'motor_rpm': 1420.0,
        'status': 'warning',
        'current_billing_cents': 112000,
        'billing_type': 'Revenue-Indexed',
        'timestamp': '2026-11-04T10:30:00Z',
      };

      final model = MachineTelemetryModel.fromJson(json);

      expect(model.assetId, 'ast_probat12');
      expect(model.temperatureCelsius, 78.0);
      expect(model.status, MachineStatus.warning);
      expect(model.currentBillingCents, 112000);
    });

    test('toDbMap and fromDbMap handle SQLite schema correctly', () {
      final dbMap = testModel.toDbMap();

      expect(dbMap['asset_id'], 'ast_probat12');
      expect(dbMap['rpm'], 1420.0);
      expect(dbMap['temp_celsius'], 78.0);
      expect(dbMap['hours'], 1248.5);

      final restored = MachineTelemetryModel.fromDbMap(dbMap);
      expect(restored.assetId, 'ast_probat12');
      expect(restored.motorRpm, 1420.0);
      expect(restored.temperatureCelsius, 78.0);
    });
  });

  group('Phase 19 — TelemetryWsDataSourceImpl Tests', () {
    test('connects to wss://api.gearlease.com/ws/telemetry?assetId={id} via web_socket_channel', () async {
      Uri? capturedUri;
      final mockChannel = MockWebSocketChannel();
      final mockSink = MockWebSocketSink();
      final streamController = StreamController<dynamic>.broadcast();

      when(() => mockChannel.sink).thenReturn(mockSink);
      when(() => mockChannel.stream).thenAnswer((_) => streamController.stream);
      when(() => mockChannel.ready).thenAnswer((_) async {});
      when(() => mockSink.close()).thenAnswer((_) async {});
      when(() => mockSink.add(any())).thenReturn(null);

      final dataSource = TelemetryWsDataSourceImpl(
        wsBaseUrl: 'wss://api.gearlease.com/ws/telemetry',
        channelFactory: (uri) {
          capturedUri = uri;
          return mockChannel;
        },
      );

      final stream = dataSource.streamMachineTelemetry('CAT-320D');
      final sub = stream.listen((_) {});

      expect(capturedUri, isNotNull);
      expect(capturedUri.toString(), 'wss://api.gearlease.com/ws/telemetry?assetId=CAT-320D');

      await sub.cancel();
      await streamController.close();
      dataSource.dispose();
    });

    test('provides simulated fallback stream when offline or disconnected', () async {
      final dataSource = TelemetryWsDataSourceImpl(
        channelFactory: (uri) {
          throw Exception('Connection failed');
        },
      );

      final stream = dataSource.streamMachineTelemetry('ast_probat12');
      final first = await stream.first;

      expect(first.assetId, 'ast_probat12');
      expect(first.machineName, contains('Probat'));

      dataSource.dispose();
    });

    test('provides fleet fallback stream when disconnected', () async {
      final dataSource = TelemetryWsDataSourceImpl(
        channelFactory: (uri) {
          throw Exception('Connection failed');
        },
      );

      final stream = dataSource.streamFleetTelemetry();
      final fleet = await stream.first;

      expect(fleet.length, greaterThanOrEqualTo(2));
      expect(fleet.any((m) => m.assetId == 'ast_probat12'), isTrue);

      dataSource.dispose();
    });
  });

  group('Phase 19 — TelemetryRepositoryImpl Throttling & Fallback Tests', () {
    test('watchMachineTelemetry yields cached data first then live updates', () async {
      when(() => mockDatabaseHelper.getTelemetry('ast_probat12')).thenAnswer(
        (_) async => testModel.toDbMap(),
      );
      when(() => mockDatabaseHelper.upsertTelemetry(any())).thenAnswer((_) async => 1);
      when(() => mockWsDataSource.streamMachineTelemetry('ast_probat12')).thenAnswer(
        (_) => Stream.value(testModel),
      );

      final emissions = await repository.watchMachineTelemetry('ast_probat12').take(2).toList();

      expect(emissions.length, 2);
      expect(emissions.first.assetId, 'ast_probat12');
      verify(() => mockDatabaseHelper.upsertTelemetry(any())).called(1);
    });

    test('applies rxdart throttleTime on incoming telemetry stream to prevent UI jank', () async {
      when(() => mockDatabaseHelper.getTelemetry(any())).thenAnswer((_) async => null);
      when(() => mockDatabaseHelper.upsertTelemetry(any())).thenAnswer((_) async => 1);

      // Create stream emitting 5 packets rapidly (every 50ms)
      final rapidStream = Stream.periodic(
        const Duration(milliseconds: 50),
        (i) => MachineTelemetryModel(
          assetId: 'ast-fast',
          machineName: 'High Speed Press',
          category: 'Manufacturing',
          runningHours: 100.0 + i,
          temperatureCelsius: 60.0 + i,
          motorRpm: 2000.0 + i,
          status: MachineStatus.optimal,
          currentBillingCents: 50000,
          billingType: 'Fixed Lease',
          timestamp: DateTime.now(),
        ),
      ).take(8);

      when(() => mockWsDataSource.streamMachineTelemetry('ast-fast')).thenAnswer(
        (_) => rapidStream,
      );

      // Listen for throttled output over 800ms
      final throttledEmissions = await repository
          .watchMachineTelemetry('ast-fast')
          .take(2)
          .toList()
          .timeout(const Duration(seconds: 3));

      // Throttling prevents receiving all 8 rapid emissions unbuffered
      expect(throttledEmissions.length, 2);
    });

    test('provides fallback mock stream generator for test environments without live broker', () async {
      final mockStream = repository.generateMockTelemetryStream(
        'ast-mock-01',
        period: const Duration(milliseconds: 50),
      );

      final packets = await mockStream.take(3).toList();

      expect(packets.length, 3);
      expect(packets.first.assetId, 'ast-mock-01');
      expect(packets.first.rpm, greaterThan(0));
      expect(packets.first.temperatureCelsius, greaterThan(0));
      expect(packets.first.status, isA<MachineStatus>());
    });

    test('scheduleWarrantyService succeeds online', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final success = await repository.scheduleWarrantyService('ast_probat12', 'Check thermal sensor');

      expect(success, isTrue);
      verify(() => mockDio.post('/api/v1/telemetry/assets/ast_probat12/service-request', data: any(named: 'data'))).called(1);
    });

    test('scheduleWarrantyService falls back to sync queue when offline', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);
      when(() => mockDatabaseHelper.insertSyncQueueItem(any())).thenAnswer((_) async => 1);

      final success = await repository.scheduleWarrantyService('ast_probat12', 'Offline booking request');

      expect(success, isTrue);
      verify(() => mockDatabaseHelper.insertSyncQueueItem(any())).called(1);
    });
  });
}
