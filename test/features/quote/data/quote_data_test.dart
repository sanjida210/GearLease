import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/error/exceptions.dart';
import 'package:gearlease/core/network/api_client.dart';
import 'package:gearlease/core/network/network_info.dart';
import 'package:gearlease/core/storage/database_helper.dart';
import 'package:gearlease/features/quote/data/datasources/quote_local_datasource.dart';
import 'package:gearlease/features/quote/data/datasources/quote_remote_datasource.dart';
import 'package:gearlease/features/quote/data/models/hardware_asset_model.dart';
import 'package:gearlease/features/quote/data/models/quote_calculation_model.dart';
import 'package:gearlease/features/quote/data/repositories/quote_repository_impl.dart';
import 'package:gearlease/features/quote/domain/entities/quote_calculation.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDio mockDio;
  late MockApiClient mockApiClient;
  late MockDatabaseHelper mockDbHelper;
  late MockNetworkInfo mockNetworkInfo;

  late QuoteRemoteDataSource remoteDataSource;
  late QuoteLocalDataSource localDataSource;
  late QuoteRepositoryImpl quoteRepository;

  final sampleAssetJson = {
    'id': 'ast-001',
    'vendor_id': 'vnd-101',
    'serial_number': 'LM-2026-9811',
    'barcode_payload': 'GL-ROAST-2026-9811',
    'barcode_symbology': 'CODE_128',
    'make': 'La Marzocco',
    'model': 'Linea PB 3-Group',
    'category': 'Commercial Espresso',
    'initial_value_cents': 2450000,
    'iot_device_identifier': 'IOT-LM-9811',
    'current_condition_rating': 'GRADE_A',
  };

  final sampleQuoteJson = {
    'quote_id': 'qte_m_998822001',
    'qualification_status': 'INSTANT_QUALIFIED',
    'repayment_type': 'REVENUE_INDEXED',
    'term_months': 36,
    'requested_amount_cents': 2450000,
    'fixed_monthly_cents': 75500,
    'revenue_share_pct': 3.5,
    'estimated_monthly_cents': 72000,
    'floor_cents': 45000,
    'cap_cents': 110000,
    'expires_in_seconds': 900,
    'options': [
      {
        'model': 'REVENUE_INDEXED',
        'revenue_share_pct': 3.5,
        'estimated_monthly_cents': 72000,
        'floor_cents': 45000,
        'cap_cents': 110000,
      },
      {
        'model': 'FIXED_MONTHLY',
        'fixed_monthly_cents': 75500,
      }
    ],
  };

  setUp(() {
    mockDio = MockDio();
    mockApiClient = MockApiClient();
    when(() => mockApiClient.dio).thenReturn(mockDio);

    mockDbHelper = MockDatabaseHelper();
    mockNetworkInfo = MockNetworkInfo();

    remoteDataSource = QuoteRemoteDataSourceImpl(apiClient: mockApiClient);
    localDataSource = QuoteLocalDataSourceImpl(databaseHelper: mockDbHelper);

    quoteRepository = QuoteRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      networkInfo: mockNetworkInfo,
    );
  });

  group('HardwareAssetModel Tests', () {
    test('fromJson and toJson map correctly', () {
      final model = HardwareAssetModel.fromJson(sampleAssetJson);

      expect(model.id, 'ast-001');
      expect(model.vendorId, 'vnd-101');
      expect(model.serialNumber, 'LM-2026-9811');
      expect(model.barcodePayload, 'GL-ROAST-2026-9811');
      expect(model.initialValueCents, 2450000);
      expect(model.displayName, 'La Marzocco Linea PB 3-Group');

      final json = model.toJson();
      expect(json['id'], 'ast-001');
      expect(json['serial_number'], 'LM-2026-9811');
    });
  });

  group('QuoteCalculationModel Tests', () {
    test('fromJson and toJson map options and fields', () {
      final model = QuoteCalculationModel.fromJson(sampleQuoteJson);

      expect(model.quoteId, 'qte_m_998822001');
      expect(model.qualificationStatus, QualificationStatus.INSTANT_QUALIFIED);
      expect(model.repaymentType, RepaymentStructureType.REVENUE_INDEXED);
      expect(model.options.length, 2);
      expect(model.options.first.floorCents, 45000);

      final json = model.toJson();
      expect(json['quote_id'], 'qte_m_998822001');
      expect(json['options'], isA<List>());
    });
  });

  group('QuoteRemoteDataSource Tests', () {
    test('lookupAssetByBarcode GETs asset on 200', () async {
      when(() => mockDio.get(
            '/api/v1/mobile/assets/barcode/GL-ROAST-2026-9811',
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/api/v1/mobile/assets/barcode/GL-ROAST-2026-9811'),
            statusCode: 200,
            data: sampleAssetJson,
          ));

      final result = await remoteDataSource.lookupAssetByBarcode('GL-ROAST-2026-9811');

      expect(result.id, 'ast-001');
      expect(result.serialNumber, 'LM-2026-9811');
    });

    test('calculateQuickQuote POSTs payload and returns QuoteCalculationModel', () async {
      when(() => mockDio.post(
            '/api/v1/mobile/quotes/quick-calculate',
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/api/v1/mobile/quotes/quick-calculate'),
            statusCode: 200,
            data: sampleQuoteJson,
          ));

      final result = await remoteDataSource.calculateQuickQuote(
        barcode: 'GL-ROAST-2026-9811',
        vendorOrgId: 'vnd-101',
        invoiceAmountCents: 2450000,
        requestedTermMonths: 36,
        repaymentType: RepaymentStructureType.REVENUE_INDEXED,
        businessEin: '12-3456789',
      );

      expect(result.quoteId, 'qte_m_998822001');
      expect(result.qualificationStatus, QualificationStatus.INSTANT_QUALIFIED);
    });

    test('throws ServerException on 404/500 API failure', () async {
      when(() => mockDio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/mobile/assets/barcode/UNKNOWN'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/mobile/assets/barcode/UNKNOWN'),
            statusCode: 404,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => remoteDataSource.lookupAssetByBarcode('UNKNOWN'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('QuoteLocalDataSource Tests', () {
    test('cacheAsset and getCachedAssetByBarcode', () async {
      when(() => mockDbHelper.upsertOfflineAsset(any())).thenAnswer((_) async => 1);
      when(() => mockDbHelper.getOfflineAssetByBarcode('GL-ROAST-2026-9811'))
          .thenAnswer((_) async => {
                'id': 'ast-001',
                'serial_number': 'LM-2026-9811',
                'make': 'La Marzocco',
                'model': 'Linea PB 3-Group',
                'msrp_cents': 2450000,
                'category': 'Commercial Espresso',
                'payload_json':
                    '{"id":"ast-001","vendor_id":"vnd-101","serial_number":"LM-2026-9811","barcode_payload":"GL-ROAST-2026-9811","barcode_symbology":"CODE_128","make":"La Marzocco","model":"Linea PB 3-Group","category":"Commercial Espresso","initial_value_cents":2450000,"iot_device_identifier":"IOT-LM-9811","current_condition_rating":"GRADE_A"}',
              });

      final asset = HardwareAssetModel.fromJson(sampleAssetJson);
      await localDataSource.cacheAsset(asset);
      final retrieved = await localDataSource.getCachedAssetByBarcode('GL-ROAST-2026-9811');

      expect(retrieved?.id, 'ast-001');
      expect(retrieved?.serialNumber, 'LM-2026-9811');
    });
  });

  group('QuoteRepositoryImpl Integration Tests', () {
    test('getAssetByBarcode fetches remote and caches locally when online', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/api/v1/mobile/assets/barcode/GL-ROAST-2026-9811'),
            statusCode: 200,
            data: sampleAssetJson,
          ));
      when(() => mockDbHelper.upsertOfflineAsset(any())).thenAnswer((_) async => 1);

      final result = await quoteRepository.getAssetByBarcode('GL-ROAST-2026-9811');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.serialNumber, 'LM-2026-9811');
      verify(() => mockDbHelper.upsertOfflineAsset(any())).called(1);
    });

    test('getAssetByBarcode returns cached local asset when offline', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);
      when(() => mockDbHelper.getOfflineAssetByBarcode('GL-ROAST-2026-9811'))
          .thenAnswer((_) async => {
                'id': 'ast-001',
                'serial_number': 'LM-2026-9811',
                'make': 'La Marzocco',
                'model': 'Linea PB 3-Group',
                'msrp_cents': 2450000,
                'category': 'Commercial Espresso',
                'payload_json':
                    '{"id":"ast-001","vendor_id":"vnd-101","serial_number":"LM-2026-9811","barcode_payload":"GL-ROAST-2026-9811","barcode_symbology":"CODE_128","make":"La Marzocco","model":"Linea PB 3-Group","category":"Commercial Espresso","initial_value_cents":2450000,"iot_device_identifier":"IOT-LM-9811","current_condition_rating":"GRADE_A"}',
              });

      final result = await quoteRepository.getAssetByBarcode('GL-ROAST-2026-9811');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.id, 'ast-001');
    });

    test('calculateQuickQuote returns client-side calculation fallback when offline', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      final result = await quoteRepository.calculateQuickQuote(
        barcode: 'GL-ROAST-2026-9811',
        vendorOrgId: 'vnd-101',
        invoiceAmountCents: 2450000,
        requestedTermMonths: 36,
        repaymentType: RepaymentStructureType.REVENUE_INDEXED,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.qualificationStatus, QualificationStatus.INSTANT_QUALIFIED);
      expect(result.dataOrNull?.repaymentType, RepaymentStructureType.REVENUE_INDEXED);
      expect(result.dataOrNull?.fixedMonthlyCents, greaterThan(0));
    });

    test('lookupAssetByBarcode delegates to barcode lookup and caches locally', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/api/v1/mobile/assets/barcode/GL-ROAST-2026-9811'),
            statusCode: 200,
            data: sampleAssetJson,
          ));
      when(() => mockDbHelper.upsertOfflineAsset(any())).thenAnswer((_) async => 1);

      final result = await quoteRepository.lookupAssetByBarcode('GL-ROAST-2026-9811');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.serialNumber, 'LM-2026-9811');
    });

    test('calculateDynamicQuote returns dynamic quote calculation', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      final result = await quoteRepository.calculateDynamicQuote(
        'GL-ROAST-2026-9811',
        48,
        PricingType.REVENUE_INDEXED,
        123456789,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.termMonths, 48);
      expect(result.dataOrNull?.pricingType, PricingType.REVENUE_INDEXED);
    });
  });
}
