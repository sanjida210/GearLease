import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/error/failures.dart';
import 'package:gearlease/core/utils/result.dart';
import 'package:gearlease/features/quote/domain/entities/hardware_asset.dart';
import 'package:gearlease/features/quote/domain/entities/quote_calculation.dart';
import 'package:gearlease/features/quote/domain/usecases/calculate_quick_quote_usecase.dart';
import 'package:gearlease/features/quote/domain/usecases/get_asset_by_barcode_usecase.dart';
import 'package:gearlease/features/quote/presentation/bloc/quote_bloc.dart';
import 'package:gearlease/features/quote/presentation/bloc/quote_event.dart';
import 'package:gearlease/features/quote/presentation/bloc/quote_state.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAssetByBarcodeUseCase extends Mock implements GetAssetByBarcodeUseCase {}

class MockCalculateQuickQuoteUseCase extends Mock implements CalculateQuickQuoteUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGetAssetByBarcodeUseCase mockGetAssetUseCase;
  late MockCalculateQuickQuoteUseCase mockCalculateQuoteUseCase;
  late QuoteBloc quoteBloc;

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

  setUpAll(() {
    registerFallbackValue(const CalculateQuickQuoteParams(
      barcode: '',
      vendorOrgId: '',
      invoiceAmountCents: 0,
      requestedTermMonths: 36,
      repaymentType: RepaymentStructureType.FIXED_MONTHLY,
    ));
  });

  setUp(() {
    mockGetAssetUseCase = MockGetAssetByBarcodeUseCase();
    mockCalculateQuoteUseCase = MockCalculateQuickQuoteUseCase();

    quoteBloc = QuoteBloc(
      getAssetByBarcodeUseCase: mockGetAssetUseCase,
      calculateQuickQuoteUseCase: mockCalculateQuoteUseCase,
    );
  });

  tearDown(() {
    quoteBloc.close();
  });

  group('QuoteBloc Tests', () {
    test('initial state is QuoteInitial', () {
      expect(quoteBloc.state, equals(QuoteInitial()));
    });

    blocTest<QuoteBloc, QuoteState>(
      'emits [QuoteAssetResolving, AssetResolved, QuoteCalculating, QuoteReady] on successful LookupAssetRequested',
      build: () {
        when(() => mockGetAssetUseCase('GL-ROAST-2026-9811'))
            .thenAnswer((_) async => Result.success(testAsset));
        when(() => mockCalculateQuoteUseCase(any()))
            .thenAnswer((_) async => Result.success(testQuote));
        return quoteBloc;
      },
      act: (bloc) => bloc.add(const LookupAssetRequested('GL-ROAST-2026-9811')),
      expect: () => [
        QuoteAssetResolving(),
        const AssetResolved(testAsset),
        QuoteCalculating(),
        const QuoteReady(
          asset: testAsset,
          calculation: testQuote,
          selectedTermMonths: 36,
          selectedPricingType: PricingType.FIXED_ANNUITY,
        ),
      ],
    );

    blocTest<QuoteBloc, QuoteState>(
      'emits [QuoteAssetResolving, QuoteErrorState] on failed LookupAssetRequested',
      build: () {
        when(() => mockGetAssetUseCase('UNKNOWN'))
            .thenAnswer((_) async => Result.failure(const ServerFailure('Asset not found')));
        return quoteBloc;
      },
      act: (bloc) => bloc.add(const LookupAssetRequested('UNKNOWN')),
      expect: () => [
        QuoteAssetResolving(),
        const QuoteErrorState('Asset not found'),
      ],
    );

    blocTest<QuoteBloc, QuoteState>(
      'emits [QuoteLoading, QuoteCalculatedState] on CalculateQuoteRequested',
      build: () {
        when(() => mockCalculateQuoteUseCase(any()))
            .thenAnswer((_) async => Result.success(testQuote));
        return quoteBloc;
      },
      act: (bloc) => bloc.add(const CalculateQuoteRequested(
        barcode: 'GL-ROAST-2026-9811',
        vendorOrgId: 'vnd-101',
        invoiceAmountCents: 2450000,
        requestedTermMonths: 36,
        repaymentType: RepaymentStructureType.REVENUE_INDEXED,
      )),
      expect: () => [
        QuoteLoading(),
        const QuoteCalculatedState(
          asset: null,
          calculation: testQuote,
          selectedTermMonths: 36,
          selectedStructure: RepaymentStructureType.REVENUE_INDEXED,
        ),
      ],
    );

    blocTest<QuoteBloc, QuoteState>(
      'emits QuoteInitial on ResetQuote',
      build: () => quoteBloc,
      act: (bloc) => bloc.add(ResetQuote()),
      expect: () => [
        QuoteInitial(),
      ],
    );
  });
}
