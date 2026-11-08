import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../entities/quote_calculation.dart';
import '../repositories/quote_repository.dart';

class CalculateQuickQuoteParams extends Equatable {
  final String barcode;
  final String vendorOrgId;
  final int invoiceAmountCents;
  final int requestedTermMonths;
  final RepaymentStructureType repaymentType;
  final String? businessEin;

  const CalculateQuickQuoteParams({
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

class CalculateQuickQuoteUseCase {
  final QuoteRepository repository;

  CalculateQuickQuoteUseCase(this.repository);

  Future<Result<QuoteCalculation, Failure>> call(CalculateQuickQuoteParams params) {
    return repository.calculateQuickQuote(
      barcode: params.barcode,
      vendorOrgId: params.vendorOrgId,
      invoiceAmountCents: params.invoiceAmountCents,
      requestedTermMonths: params.requestedTermMonths,
      repaymentType: params.repaymentType,
      businessEin: params.businessEin,
    );
  }

  /// Deterministic client-side formula for offline calculation or fast UI slider preview.
  /// Fixed: standard amortized annuity formula with 6.8% base APR.
  /// Rev-Indexed: 3.5% rev share, floor = 65% of fixed, cap = 145% of fixed.
  static QuoteCalculation calculateClientSideFallback({
    required int invoiceAmountCents,
    required int termMonths,
    required RepaymentStructureType repaymentType,
    String quoteId = 'qte_offline_preview',
  }) {
    const annualRate = 0.068;
    const monthlyRate = annualRate / 12.0;

    final numPow = math.pow(1 + monthlyRate, termMonths).toDouble();
    final factor = (monthlyRate * numPow) / (numPow - 1);
    final fixedMonthlyCents = (invoiceAmountCents * factor).round();

    final floorCents = (fixedMonthlyCents * 0.65).round();
    final capCents = (fixedMonthlyCents * 1.45).round();
    final estimatedRevIndexedCents = (fixedMonthlyCents * 0.95).round();

    final options = [
      QuoteOption(
        model: RepaymentStructureType.FIXED_MONTHLY,
        fixedMonthlyCents: fixedMonthlyCents,
      ),
      QuoteOption(
        model: RepaymentStructureType.REVENUE_INDEXED,
        revenueSharePct: 3.5,
        estimatedMonthlyCents: estimatedRevIndexedCents,
        floorCents: floorCents,
        capCents: capCents,
      ),
      QuoteOption(
        model: RepaymentStructureType.IOT_PAY_PER_USE,
        estimatedMonthlyCents: (fixedMonthlyCents * 0.85).round(),
      ),
    ];

    return QuoteCalculation(
      quoteId: quoteId,
      qualificationStatus: QualificationStatus.INSTANT_QUALIFIED,
      repaymentType: repaymentType,
      termMonths: termMonths,
      requestedAmountCents: invoiceAmountCents,
      fixedMonthlyCents: fixedMonthlyCents,
      revenueSharePct: 3.5,
      estimatedMonthlyCents: repaymentType == RepaymentStructureType.REVENUE_INDEXED
          ? estimatedRevIndexedCents
          : fixedMonthlyCents,
      floorCents: floorCents,
      capCents: capCents,
      options: options,
      expiresInSeconds: 900,
    );
  }
}
