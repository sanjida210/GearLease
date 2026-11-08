import 'package:equatable/equatable.dart';
import '../../domain/entities/quote_calculation.dart';

abstract class QuoteEvent extends Equatable {
  const QuoteEvent();

  @override
  List<Object?> get props => [];
}

class LookupAssetRequested extends QuoteEvent {
  final String barcode;

  const LookupAssetRequested(this.barcode);

  @override
  List<Object?> get props => [barcode];
}

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

class TermChanged extends QuoteEvent {
  final int termMonths;

  const TermChanged(this.termMonths);

  @override
  List<Object?> get props => [termMonths];
}

class RepaymentStructureChanged extends QuoteEvent {
  final RepaymentStructureType structureType;

  const RepaymentStructureChanged(this.structureType);

  @override
  List<Object?> get props => [structureType];
}

class ResetQuote extends QuoteEvent {}
