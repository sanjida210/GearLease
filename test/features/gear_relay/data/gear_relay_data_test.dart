import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/network/api_client.dart';
import 'package:gearlease/core/network/network_info.dart';
import 'package:gearlease/core/storage/database_helper.dart';
import 'package:gearlease/features/gear_relay/data/repositories/gear_relay_repository_impl.dart';
import 'package:gearlease/features/gear_relay/data/services/image_compression_service.dart';
import 'package:gearlease/features/gear_relay/domain/entities/inspection_angle.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}
class MockDatabaseHelper extends Mock implements DatabaseHelper {}
class MockNetworkInfo extends Mock implements NetworkInfo {}
class MockImageCompressionService extends Mock implements ImageCompressionService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiClient mockApiClient;
  late MockDio mockDio;
  late MockDatabaseHelper mockDatabaseHelper;
  late MockNetworkInfo mockNetworkInfo;
  late MockImageCompressionService mockCompressionService;
  late GearRelayRepositoryImpl repository;

  final testAngles = [
    const InspectionAngle(
      type: InspectionAngleType.frontProfile,
      title: 'Angle 1: Front Full Profile',
      description: 'Capture entire machine profile from 6-8 feet.',
      localFilePath: '/tmp/front.jpg',
      isCaptured: true,
    ),
    const InspectionAngle(
      type: InspectionAngleType.serialTag,
      title: 'Angle 2: Serial Tag & Barcode',
      description: 'Macro focus on manufacturer metal tag.',
      localFilePath: '/tmp/serial.jpg',
      isCaptured: true,
    ),
  ];

  setUp(() {
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    mockDatabaseHelper = MockDatabaseHelper();
    mockNetworkInfo = MockNetworkInfo();
    mockCompressionService = MockImageCompressionService();

    when(() => mockApiClient.dio).thenReturn(mockDio);
    when(() => mockCompressionService.compressImage(any()))
        .thenAnswer((invocation) async => '${invocation.positionalArguments[0]}_compressed.jpg');

    repository = GearRelayRepositoryImpl(
      apiClient: mockApiClient,
      databaseHelper: mockDatabaseHelper,
      networkInfo: mockNetworkInfo,
      compressionService: mockCompressionService,
    );
  });

  group('GearRelayRepositoryImpl Tests', () {
    test('submits bundle online and returns valuation ID', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          data: {'valuation_id': 'cpo_val_test123'},
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final result = await repository.submitInspectionBundle(
        assetId: 'ast_probat12',
        angles: testAngles,
      );

      expect(result, equals('cpo_val_test123'));
      verify(() => mockCompressionService.compressImage('/tmp/front.jpg')).called(1);
      verify(() => mockCompressionService.compressImage('/tmp/serial.jpg')).called(1);
      verify(() => mockDio.post('/api/v1/mobile/assets/inspection-bundle', data: any(named: 'data'))).called(1);
    });

    test('falls back to offline sync queue when network is disconnected', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);
      when(() => mockDatabaseHelper.insertSyncQueueItem(any())).thenAnswer((_) async => 1);

      final result = await repository.submitInspectionBundle(
        assetId: 'ast_probat12',
        angles: testAngles,
      );

      expect(result, startsWith('offline_cpo_'));
      verify(() => mockDatabaseHelper.insertSyncQueueItem(any())).called(1);
    });
  });
}
