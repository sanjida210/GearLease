import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/hardware_asset.dart';
import '../../domain/entities/quote_calculation.dart';
import '../../domain/usecases/calculate_quick_quote_usecase.dart';
import '../../domain/usecases/get_asset_by_barcode_usecase.dart';
import 'quote_event.dart';
import 'quote_state.dart';

class QuoteBloc extends Bloc<QuoteEvent, QuoteState> {
  final GetAssetByBarcodeUseCase getAssetByBarcodeUseCase;
  final CalculateQuickQuoteUseCase calculateQuickQuoteUseCase;

  HardwareAsset? _currentAsset;
  int _selectedTerm = 36;
  PricingType _selectedPricingType = PricingType.FIXED_ANNUITY;

  QuoteBloc({
    required this.getAssetByBarcodeUseCase,
    required this.calculateQuickQuoteUseCase,
  }) : super(QuoteInitial()) {
    on<AssetScanned>(_onAssetScanned);
    on<CalculateQuoteRequested>(_onCalculateQuoteRequested);
    on<TermChanged>(_onTermChanged);
    on<PricingModelSelected>(_onPricingModelSelected);
    on<RepaymentStructureChanged>(_onRepaymentStructureChanged);
    on<RecalculateRequested>(_onRecalculateRequested);
    on<ResetQuote>(_onResetQuote);
  }

  Future<void> _onAssetScanned(
    AssetScanned event,
    Emitter<QuoteState> emit,
  ) async {
    emit(QuoteAssetResolving());
    final result = await getAssetByBarcodeUseCase(event.barcode);

    await result.when(
      success: (asset) async {
        _currentAsset = asset;
        emit(QuoteAssetResolved(asset));

        // Automatically trigger underwriting quote calculation
        emit(QuoteCalculating());
        final invoiceAmount = asset.initialValueCents > 0 ? asset.initialValueCents : 2450000;

        final quoteResult = await calculateQuickQuoteUseCase(
          CalculateQuickQuoteParams(
            barcode: event.barcode,
            vendorOrgId: asset.vendorId.isNotEmpty ? asset.vendorId : 'default-org',
            invoiceAmountCents: invoiceAmount,
            requestedTermMonths: _selectedTerm,
            repaymentType: _selectedPricingType.toRepaymentStructureType(),
          ),
        );

        quoteResult.when(
          success: (calculation) {
            emit(QuoteReady(
              asset: asset,
              calculation: calculation,
              selectedTermMonths: _selectedTerm,
              selectedPricingType: _selectedPricingType,
            ));
          },
          failure: (failure) {
            // High-availability showroom fallback
            final fallback = CalculateQuickQuoteUseCase.calculateClientSideFallback(
              invoiceAmountCents: invoiceAmount,
              termMonths: _selectedTerm,
              repaymentType: _selectedPricingType.toRepaymentStructureType(),
            );
            emit(QuoteReady(
              asset: asset,
              calculation: fallback,
              selectedTermMonths: _selectedTerm,
              selectedPricingType: _selectedPricingType,
            ));
          },
        );
      },
      failure: (failure) {
        emit(QuoteError(failure.message));
      },
    );
  }

  Future<void> _onCalculateQuoteRequested(
    CalculateQuoteRequested event,
    Emitter<QuoteState> emit,
  ) async {
    emit(QuoteCalculating());
    final result = await calculateQuickQuoteUseCase(
      CalculateQuickQuoteParams(
        barcode: event.barcode,
        vendorOrgId: event.vendorOrgId,
        invoiceAmountCents: event.invoiceAmountCents,
        requestedTermMonths: event.requestedTermMonths,
        repaymentType: event.repaymentType,
        businessEin: event.businessEin,
      ),
    );

    result.when(
      success: (calculation) {
        _selectedTerm = event.requestedTermMonths;
        _selectedPricingType = event.repaymentType.toPricingType();
        emit(QuoteReady(
          asset: _currentAsset,
          calculation: calculation,
          selectedTermMonths: event.requestedTermMonths,
          selectedPricingType: _selectedPricingType,
        ));
      },
      failure: (failure) => emit(QuoteError(failure.message)),
    );
  }

  void _onTermChanged(
    TermChanged event,
    Emitter<QuoteState> emit,
  ) {
    _selectedTerm = event.termMonths;
    final currentState = state;
    if (currentState is QuoteReady) {
      final updated = CalculateQuickQuoteUseCase.calculateClientSideFallback(
        invoiceAmountCents: currentState.calculation.requestedAmountCents > 0
            ? currentState.calculation.requestedAmountCents
            : 2450000,
        termMonths: event.termMonths,
        repaymentType: _selectedPricingType.toRepaymentStructureType(),
        quoteId: currentState.calculation.quoteId,
      );

      emit(currentState.copyWith(
        calculation: updated,
        selectedTermMonths: event.termMonths,
      ));
    }
  }

  void _onPricingModelSelected(
    PricingModelSelected event,
    Emitter<QuoteState> emit,
  ) {
    _selectedPricingType = event.type;
    final currentState = state;
    if (currentState is QuoteReady) {
      final updated = CalculateQuickQuoteUseCase.calculateClientSideFallback(
        invoiceAmountCents: currentState.calculation.requestedAmountCents > 0
            ? currentState.calculation.requestedAmountCents
            : 2450000,
        termMonths: _selectedTerm,
        repaymentType: event.type.toRepaymentStructureType(),
        quoteId: currentState.calculation.quoteId,
      );

      emit(currentState.copyWith(
        calculation: updated,
        selectedPricingType: event.type,
      ));
    }
  }

  void _onRepaymentStructureChanged(
    RepaymentStructureChanged event,
    Emitter<QuoteState> emit,
  ) {
    add(PricingModelSelected(event.structureType.toPricingType()));
  }

  Future<void> _onRecalculateRequested(
    RecalculateRequested event,
    Emitter<QuoteState> emit,
  ) async {
    final currentState = state;
    if (currentState is QuoteReady) {
      emit(QuoteCalculating());

      final invoiceAmount = currentState.calculation.requestedAmountCents > 0
          ? currentState.calculation.requestedAmountCents
          : (_currentAsset?.initialValueCents ?? 2450000);

      final result = await calculateQuickQuoteUseCase(
        CalculateQuickQuoteParams(
          barcode: _currentAsset?.serialNumber ?? 'RECALC',
          vendorOrgId: _currentAsset?.vendorId ?? 'default-org',
          invoiceAmountCents: invoiceAmount,
          requestedTermMonths: _selectedTerm,
          repaymentType: _selectedPricingType.toRepaymentStructureType(),
        ),
      );

      result.when(
        success: (calculation) {
          emit(QuoteReady(
            asset: _currentAsset ?? currentState.asset,
            calculation: calculation,
            selectedTermMonths: _selectedTerm,
            selectedPricingType: _selectedPricingType,
          ));
        },
        failure: (_) {
          final fallback = CalculateQuickQuoteUseCase.calculateClientSideFallback(
            invoiceAmountCents: invoiceAmount,
            termMonths: _selectedTerm,
            repaymentType: _selectedPricingType.toRepaymentStructureType(),
            quoteId: currentState.calculation.quoteId,
          );
          emit(QuoteReady(
            asset: _currentAsset ?? currentState.asset,
            calculation: fallback,
            selectedTermMonths: _selectedTerm,
            selectedPricingType: _selectedPricingType,
          ));
        },
      );
    }
  }

  void _onResetQuote(
    ResetQuote event,
    Emitter<QuoteState> emit,
  ) {
    _currentAsset = null;
    _selectedTerm = 36;
    _selectedPricingType = PricingType.FIXED_ANNUITY;
    emit(QuoteInitial());
  }
}
