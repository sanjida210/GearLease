import 'package:equatable/equatable.dart';
import '../../domain/entities/hardware_asset.dart';
import '../../domain/entities/quote_calculation.dart';

abstract class QuoteState extends Equatable {
  const QuoteState();

  @override
  List<Object?> get props => [];
}

class QuoteInitial extends QuoteState {}

class QuoteLoading extends QuoteState {}

class AssetResolved extends QuoteState {
  final HardwareAsset asset;

  const AssetResolved(this.asset);

  @override
  List<Object?> get props => [asset];
}

class QuoteCalculatedState extends QuoteState {
  final HardwareAsset? asset;
  final QuoteCalculation calculation;
  final int selectedTermMonths;
  final RepaymentStructureType selectedStructure;

  const QuoteCalculatedState({
    this.asset,
    required this.calculation,
    required this.selectedTermMonths,
    required this.selectedStructure,
  });

  QuoteCalculatedState copyWith({
    HardwareAsset? asset,
    QuoteCalculation? calculation,
    int? selectedTermMonths,
    RepaymentStructureType? selectedStructure,
  }) {
    return QuoteCalculatedState(
      asset: asset ?? this.asset,
      calculation: calculation ?? this.calculation,
      selectedTermMonths: selectedTermMonths ?? this.selectedTermMonths,
      selectedStructure: selectedStructure ?? this.selectedStructure,
    );
  }

  @override
  List<Object?> get props => [
        asset,
        calculation,
        selectedTermMonths,
        selectedStructure,
      ];
}

class QuoteErrorState extends QuoteState {
  final String errorMessage;

  const QuoteErrorState(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
