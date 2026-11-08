import 'package:equatable/equatable.dart';
import '../../domain/entities/quote_calculation.dart';

abstract class QuoteEvent extends Equatable {
  const QuoteEvent();

  @override
  List<Object?> get props => [];
}

/// Asset Scanned event with barcode (Phase 14 requirement).
class AssetScanned extends QuoteEvent {
  final String barcode;

  const AssetScanned(this.barcode);

  @override
  List<Object?> get props => [barcode];
}

/// Backward compatibility alias for AssetScanned.
typedef LookupAssetRequested = AssetScanned;

/// Term length changed (e.g. 36, 48, 60 months) (Phase 14 requirement).
class TermChanged extends QuoteEvent {
  final int termMonths;

  const TermChanged(this.termMonths);

  @override
  List<Object?> get props => [termMonths];
}

/// Pricing model selected (Fixed Annuity, Revenue-Indexed, Pay-Per-Use) (Phase 14 requirement).
class PricingModelSelected extends QuoteEvent {
  final PricingType type;

  const PricingModelSelected(this.type);

  @override
  List<Object?> get props => [type];
}

/// Backward compatibility adapter for legacy RepaymentStructureType events.
class RepaymentStructureChanged extends QuoteEvent {
  final RepaymentStructureType structureType;

  const RepaymentStructureChanged(this.structureType);

  PricingType get pricingType => structureType.toPricingType();

  @override
  List<Object?> get props => [structureType];
}

/// Manual trigger to recalculate current quote (Phase 14 requirement).
class RecalculateRequested extends QuoteEvent {}

/// Reset quote session back to initial state (Phase 14 requirement).
class ResetQuote extends QuoteEvent {}

/// Backward compatibility for explicit calculate quote calls.
class CalculateQuoteRequested extends QuoteEvent {
  final String barcode;
  final String vendorOrgId;
  final int invoiceAmountCents;
  final int requestedTermMonths;
  final RepaymentStructureType repaymentType;
  final String? businessEin;

  const CalculateQuoteRequested({
    required this.barcode,
    required this.vendorOrgId,
    required this.invoiceAmountCents,
    required this.requestedTermMonths,
    required this.repaymentType,
    this.businessEin,
  });

  @override
  List<Object?> get props => [
        barcode,
        vendorOrgId,
        invoiceAmountCents,
        requestedTermMonths,
        repaymentType,
        businessEin,
      ];
}
