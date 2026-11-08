import 'package:equatable/equatable.dart';
import '../../domain/entities/hardware_asset.dart';
import '../../domain/entities/quote_calculation.dart';

abstract class QuoteState extends Equatable {
  const QuoteState();

  @override
  List<Object?> get props => [];
}

/// Initial uninitialized state.
class QuoteInitial extends QuoteState {}

/// State while barcode asset lookup is in flight.
class QuoteAssetResolving extends QuoteState {}

/// State once hardware asset has been successfully resolved from barcode.
class QuoteAssetResolved extends QuoteState {
  final HardwareAsset asset;

  const QuoteAssetResolved(this.asset);

  @override
  List<Object?> get props => [asset];
}

/// Backward compatibility alias for QuoteAssetResolved.
typedef AssetResolved = QuoteAssetResolved;

/// State while underwriting computation / calculation is in flight.
class QuoteCalculating extends QuoteState {}

/// Backward compatibility alias for QuoteCalculating.
typedef QuoteLoading = QuoteCalculating;

/// State when underwriting quote calculation is ready.
class QuoteReady extends QuoteState {
  final HardwareAsset? asset;
  final QuoteCalculation calculation;
  final int selectedTermMonths;
  final PricingType selectedPricingType;

  const QuoteReady({
    this.asset,
    required this.calculation,
    this.selectedTermMonths = 36,
    PricingType? selectedPricingType,
    RepaymentStructureType? selectedStructure,
  }) : selectedPricingType = selectedPricingType ??
            (selectedStructure == RepaymentStructureType.REVENUE_INDEXED
                ? PricingType.REVENUE_INDEXED
                : (selectedStructure == RepaymentStructureType.IOT_PAY_PER_USE
                    ? PricingType.PAY_PER_USE
                    : PricingType.FIXED_ANNUITY));

  RepaymentStructureType get selectedStructure =>
      selectedPricingType.toRepaymentStructureType();

  QuoteReady copyWith({
    HardwareAsset? asset,
    QuoteCalculation? calculation,
    int? selectedTermMonths,
    PricingType? selectedPricingType,
    RepaymentStructureType? selectedStructure,
  }) {
    return QuoteReady(
      asset: asset ?? this.asset,
      calculation: calculation ?? this.calculation,
      selectedTermMonths: selectedTermMonths ?? this.selectedTermMonths,
      selectedPricingType: selectedPricingType ??
          (selectedStructure != null
              ? selectedStructure.toPricingType()
              : this.selectedPricingType),
    );
  }

  @override
  List<Object?> get props => [
        asset,
        calculation,
        selectedTermMonths,
        selectedPricingType,
      ];
}

/// Backward compatibility alias for QuoteReady.
typedef QuoteCalculatedState = QuoteReady;

/// State on underwriting or lookup failure.
class QuoteError extends QuoteState {
  final String message;

  const QuoteError(this.message);

  String get errorMessage => message;

  @override
  List<Object?> get props => [message];
}

/// Backward compatibility alias for QuoteError.
typedef QuoteErrorState = QuoteError;
