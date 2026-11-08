import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/hardware_asset.dart';
import '../../domain/usecases/calculate_quick_quote_usecase.dart';
import '../../domain/usecases/get_asset_by_barcode_usecase.dart';
import 'quote_event.dart';
import 'quote_state.dart';

class QuoteBloc extends Bloc<QuoteEvent, QuoteState> {
  final GetAssetByBarcodeUseCase getAssetByBarcodeUseCase;
  final CalculateQuickQuoteUseCase calculateQuickQuoteUseCase;

  HardwareAsset? _currentAsset;

  QuoteBloc({
    required this.getAssetByBarcodeUseCase,
    required this.calculateQuickQuoteUseCase,
  }) : super(QuoteInitial()) {
    on<LookupAssetRequested>(_onLookupAssetRequested);
    on<CalculateQuoteRequested>(_onCalculateQuoteRequested);
    on<TermChanged>(_onTermChanged);
    on<RepaymentStructureChanged>(_onRepaymentStructureChanged);
    on<ResetQuote>(_onResetQuote);
  }

  Future<void> _onLookupAssetRequested(
    LookupAssetRequested event,
    Emitter<QuoteState> emit,
  ) async {
    emit(QuoteLoading());
    final result = await getAssetByBarcodeUseCase(event.barcode);
    result.when(
      success: (asset) {
        _currentAsset = asset;
        emit(AssetResolved(asset));
      },
      failure: (failure) => emit(QuoteErrorState(failure.toString())),
    );
  }

  Future<void> _onCalculateQuoteRequested(
    CalculateQuoteRequested event,
    Emitter<QuoteState> emit,
  ) async {
    emit(QuoteLoading());
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
        emit(QuoteCalculatedState(
          asset: _currentAsset,
          calculation: calculation,
          selectedTermMonths: event.requestedTermMonths,
          selectedStructure: event.repaymentType,
        ));
      },
      failure: (failure) => emit(QuoteErrorState(failure.toString())),
    );
  }

  void _onTermChanged(
    TermChanged event,
    Emitter<QuoteState> emit,
  ) {
    final currentState = state;
    if (currentState is QuoteCalculatedState) {
      final updated = CalculateQuickQuoteUseCase.calculateClientSideFallback(
        invoiceAmountCents: currentState.calculation.requestedAmountCents,
        termMonths: event.termMonths,
        repaymentType: currentState.selectedStructure,
        quoteId: currentState.calculation.quoteId,
      );

      emit(currentState.copyWith(
        calculation: updated,
        selectedTermMonths: event.termMonths,
      ));
    }
  }

  void _onRepaymentStructureChanged(
    RepaymentStructureChanged event,
    Emitter<QuoteState> emit,
  ) {
    final currentState = state;
    if (currentState is QuoteCalculatedState) {
      final updated = CalculateQuickQuoteUseCase.calculateClientSideFallback(
        invoiceAmountCents: currentState.calculation.requestedAmountCents,
        termMonths: currentState.selectedTermMonths,
        repaymentType: event.structureType,
        quoteId: currentState.calculation.quoteId,
      );

      emit(currentState.copyWith(
        calculation: updated,
        selectedStructure: event.structureType,
      ));
    }
  }

  void _onResetQuote(
    ResetQuote event,
    Emitter<QuoteState> emit,
  ) {
    _currentAsset = null;
    emit(QuoteInitial());
  }
}
