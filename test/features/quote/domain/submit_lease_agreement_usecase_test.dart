import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/network/api_client.dart';
import 'package:gearlease/core/network/network_info.dart';
import 'package:gearlease/features/offline_sync/domain/entities/sync_item.dart';
import 'package:gearlease/features/offline_sync/domain/repositories/sync_repository.dart';
import 'package:gearlease/features/quote/domain/usecases/submit_lease_agreement_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}
class MockSyncRepository extends Mock implements SyncRepository {}
class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiClient mockApiClient;
  late MockDio mockDio;
  late MockSyncRepository mockSyncRepository;
  late MockNetworkInfo mockNetworkInfo;
  late SubmitLeaseAgreementUseCase useCase;

  final testSignatureBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02]);

  final testParams = SubmitLeaseAgreementParams(
    quoteId: 'qte-998822',
    lesseeBusinessName: 'Apex Roasting Works LLC',
    equipmentSerial: 'LM-2026-9811',
    termMonths: 36,
    monthlyBaseCents: 75500,
    pricingType: 'REVENUE_INDEXED',
    auditHash: 'mock-sha256-audit-fingerprint',
    signatureBytes: testSignatureBytes,
    signatureSvg: '<svg></svg>',
    businessEin: '12-3456789',
    metadata: const {'stroke_count': 18, 'platform': 'android'},
  );

  setUpAll(() {
    registerFallbackValue(SyncItem(
      id: 'mock-id',
      idempotencyKey: 'mock-key',
      actionType: 'SUBMIT_LEASE_AGREEMENT',
      payloadJson: '{}',
      createdAt: DateTime.now(),
    ));
    registerFallbackValue(Options());
  });

  setUp(() {
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    mockSyncRepository = MockSyncRepository();
    mockNetworkInfo = MockNetworkInfo();

    when(() => mockApiClient.dio).thenReturn(mockDio);

    useCase = SubmitLeaseAgreementUseCase(
      apiClient: mockApiClient,
      syncRepository: mockSyncRepository,
      networkInfo: mockNetworkInfo,
    );
  });

  group('SubmitLeaseAgreementUseCase Unit Tests', () {
    test('online: sends POST /api/v1/leases/sign with idempotency key, audit hash, and base64 signature', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/api/v1/leases/sign'),
            statusCode: 200,
            data: {
              'lease_id': 'LSE-2026-98110',
              'status': 'EXECUTED',
              'pdf_url': 'https://api.gearlease.io/leases/LSE-2026-98110/doc.pdf',
            },
          ));

      final result = await useCase(testParams);

      expect(result.isSuccess, isTrue);
      final data = result.dataOrNull;
      expect(data, isNotNull);
      expect(data!.leaseId, 'LSE-2026-98110');
      expect(data.status, 'EXECUTED');
      expect(data.isOfflineQueued, isFalse);
      expect(data.pdfUrl, contains('LSE-2026-98110'));
      expect(data.idempotencyKey, isNotEmpty);

      // Verify POST call payload
      verify(() => mockDio.post(
            '/api/v1/leases/sign',
            data: any(
              named: 'data',
              that: isA<Map<String, dynamic>>().having(
                (d) => d['audit_hash'],
                'audit_hash',
                'mock-sha256-audit-fingerprint',
              ).having(
                (d) => d['signature_base64'],
                'signature_base64',
                base64Encode(testSignatureBytes),
              ).having(
                (d) => d['lessee_business_name'],
                'lessee_business_name',
                'Apex Roasting Works LLC',
              ),
            ),
            options: any(named: 'options'),
          )).called(1);

      verifyNever(() => mockSyncRepository.enqueueSyncItem(any()));
    });

    test('offline: enqueues directly into SyncRepository and returns instant offline Lease ID', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);
      when(() => mockSyncRepository.enqueueSyncItem(any())).thenAnswer((_) async {});

      final result = await useCase(testParams);

      expect(result.isSuccess, isTrue);
      final data = result.dataOrNull;
      expect(data, isNotNull);
      expect(data!.isOfflineQueued, isTrue);
      expect(data.status, 'QUEUED_OFFLINE');
      expect(data.leaseId, startsWith('OFFLINE-'));
      expect(data.idempotencyKey, isNotEmpty);

      verify(() => mockSyncRepository.enqueueSyncItem(any(
            that: isA<SyncItem>().having(
              (item) => item.actionType,
              'actionType',
              'SUBMIT_LEASE_AGREEMENT',
            ).having(
              (item) => item.payloadJson,
              'payloadJson',
              contains('Apex Roasting Works LLC'),
            ),
          ))).called(1);

      verifyZeroInteractions(mockDio);
    });
  });
}
