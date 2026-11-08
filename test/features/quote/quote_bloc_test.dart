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
    serialNumber: 'CAT-320D-2024',
    barcodePayload: 'CAT-320D-2024',
    make: 'Caterpillar',
    model: '320D Hydraulic Excavator',
    category: 'Heavy Earthmoving',
    msrpCents: 24500000,
  );

  const testCalculation = QuoteCalculation(
    quoteId: 'qte_test_123',
    termMonths: 36,
    monthlyBaseCents: 75500,
    requestedAmountCents: 24500000,
    pricingType: PricingType.FIXED_ANNUITY,
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

  group('Phase 14 QuoteBloc State Machine Tests', () {
    test('initial state is QuoteInitial', () {
      expect(quoteBloc.state, equals(QuoteInitial()));
    });

    blocTest<QuoteBloc, QuoteState>(
      'emits [QuoteAssetResolving, QuoteAssetResolved, QuoteCalculating, QuoteReady] on AssetScanned success',
      build: () {
        when(() => mockGetAssetUseCase('CAT-320D-2024'))
            .thenAnswer((_) async => Result.success(testAsset));
        when(() => mockCalculateQuoteUseCase(any()))
            .thenAnswer((_) async => Result.success(testCalculation));
        return quoteBloc;
      },
      act: (bloc) => bloc.add(const AssetScanned('CAT-320D-2024')),
      expect: () => [
        QuoteAssetResolving(),
        const QuoteAssetResolved(testAsset),
        QuoteCalculating(),
        const QuoteReady(
          asset: testAsset,
          calculation: testCalculation,
          selectedTermMonths: 36,
          selectedPricingType: PricingType.FIXED_ANNUITY,
        ),
      ],
    );

    blocTest<QuoteBloc, QuoteState>(
      'emits [QuoteAssetResolving, QuoteError] on AssetScanned failure',
      build: () {
        when(() => mockGetAssetUseCase('UNKNOWN'))
            .thenAnswer((_) async => Result.failure(const ServerFailure('Asset not found')));
        return quoteBloc;
      },
      act: (bloc) => bloc.add(const AssetScanned('UNKNOWN')),
      expect: () => [
        QuoteAssetResolving(),
        const QuoteError('Asset not found'),
      ],
    );

    blocTest<QuoteBloc, QuoteState>(
      'automatically triggers recalculation when TermChanged (36 -> 48)',
      build: () => quoteBloc,
      seed: () => const QuoteReady(
        asset: testAsset,
        calculation: testCalculation,
        selectedTermMonths: 36,
        selectedPricingType: PricingType.FIXED_ANNUITY,
      ),
      act: (bloc) => bloc.add(const TermChanged(48)),
      expect: () => [
        isA<QuoteReady>()
            .having((s) => s.selectedTermMonths, 'selectedTermMonths', 48)
            .having((s) => s.calculation.termMonths, 'calculation.termMonths', 48)
            .having((s) => s.calculation.monthlyBaseCents, 'calculation.monthlyBaseCents', greaterThan(0)),
      ],
    );

    blocTest<QuoteBloc, QuoteState>(
      'automatically triggers recalculation when PricingModelSelected (FIXED_ANNUITY -> REVENUE_INDEXED)',
      build: () => quoteBloc,
      seed: () => const QuoteReady(
        asset: testAsset,
        calculation: testCalculation,
        selectedTermMonths: 36,
        selectedPricingType: PricingType.FIXED_ANNUITY,
      ),
      act: (bloc) => bloc.add(const PricingModelSelected(PricingType.REVENUE_INDEXED)),
      expect: () => [
        isA<QuoteReady>()
            .having((s) => s.selectedPricingType, 'selectedPricingType', PricingType.REVENUE_INDEXED)
            .having((s) => s.calculation.pricingType, 'calculation.pricingType', PricingType.REVENUE_INDEXED)
            .having((s) => s.calculation.revenueSharePercent, 'calculation.revenueSharePercent', 3.5),
      ],
    );

    blocTest<QuoteBloc, QuoteState>(
      'emits [QuoteCalculating, QuoteReady] on RecalculateRequested',
      build: () {
        when(() => mockCalculateQuoteUseCase(any()))
            .thenAnswer((_) async => Result.success(testCalculation));
        return quoteBloc;
      },
      seed: () => const QuoteReady(
        asset: testAsset,
        calculation: testCalculation,
        selectedTermMonths: 36,
        selectedPricingType: PricingType.FIXED_ANNUITY,
      ),
      act: (bloc) => bloc.add(RecalculateRequested()),
      expect: () => [
        QuoteCalculating(),
        isA<QuoteReady>(),
      ],
    );

    blocTest<QuoteBloc, QuoteState>(
      'emits [QuoteAssetResolving, QuoteAssetResolved, QuoteCalculating, QuoteReady] with fallback calculation when server quote fails during AssetScanned',
      build: () {
        when(() => mockGetAssetUseCase('CAT-320D-2024'))
            .thenAnswer((_) async => Result.success(testAsset));
        when(() => mockCalculateQuoteUseCase(any()))
            .thenAnswer((_) async => Result.failure(const ServerFailure('Calculation server error')));
        return quoteBloc;
      },
      act: (bloc) => bloc.add(const AssetScanned('CAT-320D-2024')),
      expect: () => [
        QuoteAssetResolving(),
        const QuoteAssetResolved(testAsset),
        QuoteCalculating(),
        isA<QuoteReady>()
            .having((s) => s.asset, 'asset', testAsset)
            .having((s) => s.calculation.isOfflineEstimate, 'isOfflineEstimate', isTrue),
      ],
    );

    blocTest<QuoteBloc, QuoteState>(
      'emits [QuoteCalculating, QuoteError] on CalculateQuoteRequested failure',
      build: () {
        when(() => mockCalculateQuoteUseCase(any()))
            .thenAnswer((_) async => Result.failure(const ServerFailure('Recalculation engine timeout')));
        return quoteBloc;
      },
      act: (bloc) => bloc.add(const CalculateQuoteRequested(
        barcode: 'CAT-320D-2024',
        vendorOrgId: 'vnd-101',
        invoiceAmountCents: 24500000,
        requestedTermMonths: 36,
        repaymentType: RepaymentStructureType.FIXED_MONTHLY,
      )),
      expect: () => [
        QuoteCalculating(),
        const QuoteError('Recalculation engine timeout'),
      ],
    );

    blocTest<QuoteBloc, QuoteState>(
      'emits QuoteInitial on ResetQuote',
      build: () => quoteBloc,
      seed: () => const QuoteReady(
        asset: testAsset,
        calculation: testCalculation,
        selectedTermMonths: 36,
        selectedPricingType: PricingType.FIXED_ANNUITY,
      ),
      act: (bloc) => bloc.add(ResetQuote()),
      expect: () => [
        QuoteInitial(),
      ],
    );
  });
}
