import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/error/failures.dart';
import 'package:gearlease/core/utils/result.dart';
import 'package:gearlease/features/quote/domain/entities/hardware_asset.dart';
import 'package:gearlease/features/quote/domain/entities/quote_calculation.dart';
import 'package:gearlease/features/quote/domain/repositories/quote_repository.dart';
import 'package:gearlease/features/quote/domain/usecases/calculate_quick_quote_usecase.dart';
import 'package:gearlease/features/quote/domain/usecases/get_asset_by_barcode_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockQuoteRepository extends Mock implements QuoteRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockQuoteRepository mockRepository;
  late GetAssetByBarcodeUseCase getAssetUseCase;
  late CalculateQuickQuoteUseCase calculateQuoteUseCase;

  const testAsset = HardwareAsset(
    id: 'ast-001',
    vendorId: 'vnd-101',
    serialNumber: 'LM-2026-9811',
    barcodePayload: 'GL-ROAST-2026-9811',
    barcodeSymbology: 'CODE_128',
    make: 'La Marzocco',
    model: 'Linea PB 3-Group',
    category: 'Commercial Espresso',
    initialValueCents: 2450000,
    iotDeviceIdentifier: 'IOT-LM-9811',
    currentConditionRating: 'GRADE_A',
  );

  const testQuote = QuoteCalculation(
    quoteId: 'qte_m_998822001',
    qualificationStatus: QualificationStatus.INSTANT_QUALIFIED,
    repaymentType: RepaymentStructureType.REVENUE_INDEXED,
    termMonths: 36,
    requestedAmountCents: 2450000,
    fixedMonthlyCents: 75500,
    revenueSharePct: 3.5,
    estimatedMonthlyCents: 72000,
    floorCents: 45000,
    capCents: 110000,
    expiresInSeconds: 900,
  );

  setUp(() {
    mockRepository = MockQuoteRepository();
    getAssetUseCase = GetAssetByBarcodeUseCase(mockRepository);
    calculateQuoteUseCase = CalculateQuickQuoteUseCase(mockRepository);
  });

  group('HardwareAsset Entity Tests', () {
    test('supports value equality', () {
      const assetA = HardwareAsset(
        id: 'ast-001',
        vendorId: 'vnd-101',
        serialNumber: 'LM-2026-9811',
        barcodePayload: 'GL-ROAST-2026-9811',
        barcodeSymbology: 'CODE_128',
        make: 'La Marzocco',
        model: 'Linea PB 3-Group',
        category: 'Commercial Espresso',
        initialValueCents: 2450000,
        iotDeviceIdentifier: 'IOT-LM-9811',
        currentConditionRating: 'GRADE_A',
      );

      expect(testAsset, equals(assetA));
    });
  });

  group('QuoteCalculation Entity Tests', () {
    test('supports value equality and enum mapping', () {
      expect(testQuote.qualificationStatus, QualificationStatus.INSTANT_QUALIFIED);
      expect(testQuote.repaymentType, RepaymentStructureType.REVENUE_INDEXED);
      expect(testQuote.termMonths, 36);
      expect(testQuote.floorCents, 45000);
      expect(testQuote.capCents, 110000);
    });
  });

  group('GetAssetByBarcodeUseCase Tests', () {
    test('calls repository and returns asset on success', () async {
      when(() => mockRepository.getAssetByBarcode('GL-ROAST-2026-9811'))
          .thenAnswer((_) async => Result.success(testAsset));

      final result = await getAssetUseCase('GL-ROAST-2026-9811');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.serialNumber, 'LM-2026-9811');
      verify(() => mockRepository.getAssetByBarcode('GL-ROAST-2026-9811')).called(1);
    });

    test('returns Failure when barcode asset not found', () async {
      when(() => mockRepository.getAssetByBarcode('UNKNOWN'))
          .thenAnswer((_) async => Result.failure(const ServerFailure('Asset not found', statusCode: 404)));

      final result = await getAssetUseCase('UNKNOWN');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, 'Asset not found');
    });
  });

  group('CalculateQuickQuoteUseCase Tests', () {
    test('calls repository with params and returns QuoteCalculation', () async {
      when(() => mockRepository.calculateQuickQuote(
            barcode: 'GL-ROAST-2026-9811',
            vendorOrgId: 'vnd-101',
            invoiceAmountCents: 2450000,
            requestedTermMonths: 36,
            repaymentType: RepaymentStructureType.REVENUE_INDEXED,
            businessEin: '12-3456789',
          )).thenAnswer((_) async => Result.success(testQuote));

      final result = await calculateQuoteUseCase(
        const CalculateQuickQuoteParams(
          barcode: 'GL-ROAST-2026-9811',
          vendorOrgId: 'vnd-101',
          invoiceAmountCents: 2450000,
          requestedTermMonths: 36,
          repaymentType: RepaymentStructureType.REVENUE_INDEXED,
          businessEin: '12-3456789',
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.quoteId, 'qte_m_998822001');
      verify(() => mockRepository.calculateQuickQuote(
            barcode: 'GL-ROAST-2026-9811',
            vendorOrgId: 'vnd-101',
            invoiceAmountCents: 2450000,
            requestedTermMonths: 36,
            repaymentType: RepaymentStructureType.REVENUE_INDEXED,
            businessEin: '12-3456789',
          )).called(1);
    });

    test('calculateClientSideFallback computes sane values offline', () {
      final fallback = CalculateQuickQuoteUseCase.calculateClientSideFallback(
        invoiceAmountCents: 2400000, // $24,000
        termMonths: 36,
        repaymentType: RepaymentStructureType.FIXED_MONTHLY,
      );

      expect(fallback.qualificationStatus, QualificationStatus.INSTANT_QUALIFIED);
      expect(fallback.repaymentType, RepaymentStructureType.FIXED_MONTHLY);
      expect(fallback.fixedMonthlyCents, greaterThan(0));
      expect(fallback.termMonths, 36);
    });
  });
}
