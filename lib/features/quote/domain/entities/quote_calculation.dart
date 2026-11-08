import 'package:equatable/equatable.dart';

// ignore_for_file: constant_identifier_names

enum PricingType {
  FIXED_ANNUITY,
  REVENUE_INDEXED,
  PAY_PER_USE,
}

enum RepaymentStructureType {
  FIXED_MONTHLY,
  REVENUE_INDEXED,
  IOT_PAY_PER_USE,
}

extension PricingTypeX on PricingType {
  RepaymentStructureType toRepaymentStructureType() {
    switch (this) {
      case PricingType.FIXED_ANNUITY:
        return RepaymentStructureType.FIXED_MONTHLY;
      case PricingType.REVENUE_INDEXED:
        return RepaymentStructureType.REVENUE_INDEXED;
      case PricingType.PAY_PER_USE:
        return RepaymentStructureType.IOT_PAY_PER_USE;
    }
  }
}

extension RepaymentStructureTypeX on RepaymentStructureType {
  PricingType toPricingType() {
    switch (this) {
      case RepaymentStructureType.FIXED_MONTHLY:
        return PricingType.FIXED_ANNUITY;
      case RepaymentStructureType.REVENUE_INDEXED:
        return PricingType.REVENUE_INDEXED;
      case RepaymentStructureType.IOT_PAY_PER_USE:
        return PricingType.PAY_PER_USE;
    }
  }
}

enum QualificationStatus {
  INSTANT_QUALIFIED,
  REQUIRES_MANUAL_REVIEW,
  DECLINED,
}

class QuoteOption extends Equatable {
  final RepaymentStructureType model;
  final int? fixedMonthlyCents;
  final double? revenueSharePct;
  final int? estimatedMonthlyCents;
  final int? floorCents;
  final int? capCents;

  const QuoteOption({
    required this.model,
    this.fixedMonthlyCents,
    this.revenueSharePct,
    this.estimatedMonthlyCents,
    this.floorCents,
    this.capCents,
  });

  @override
  List<Object?> get props => [
        model,
        fixedMonthlyCents,
        revenueSharePct,
        estimatedMonthlyCents,
        floorCents,
        capCents,
      ];
}

class QuoteCalculation extends Equatable {
  static const String flagOfflineEstimate = 'OFFLINE_ESTIMATE';
  static const String flagLive = 'LIVE';

  final String quoteId;
  final QualificationStatus qualificationStatus;
  final PricingType pricingType;
  final RepaymentStructureType repaymentType;
  final int termMonths;
  final int requestedAmountCents;
  final int monthlyBaseCents;
  final double? revenueSharePercent;
  final int? estimatedMonthlyCents;
  final int? floorCents;
  final int? capCents;
  final String riskTier;
  final int estimatedUnderwriteSeconds;
  final bool isOfflineEstimate;
  final String estimateFlag;
  final List<QuoteOption> options;
  final int expiresInSeconds;

  const QuoteCalculation({
    this.quoteId = '',
    this.qualificationStatus = QualificationStatus.INSTANT_QUALIFIED,
    PricingType? pricingType,
    RepaymentStructureType? repaymentType,
    required this.termMonths,
    this.requestedAmountCents = 0,
    int? monthlyBaseCents,
    int? fixedMonthlyCents,
    double? revenueSharePercent,
    double? revenueSharePct,
    this.estimatedMonthlyCents,
    this.floorCents,
    this.capCents,
    this.riskTier = 'LOW',
    this.estimatedUnderwriteSeconds = 90,
    bool? isOfflineEstimate,
    String? estimateFlag,
    this.options = const [],
    this.expiresInSeconds = 900,
  })  : isOfflineEstimate = isOfflineEstimate ?? (estimateFlag == 'OFFLINE_ESTIMATE'),
        estimateFlag = estimateFlag ??
            ((isOfflineEstimate ?? false) ? 'OFFLINE_ESTIMATE' : 'LIVE'),
        monthlyBaseCents = monthlyBaseCents ?? fixedMonthlyCents ?? 0,
        revenueSharePercent = revenueSharePercent ?? revenueSharePct,
        pricingType = pricingType ??
            (repaymentType == RepaymentStructureType.REVENUE_INDEXED
                ? PricingType.REVENUE_INDEXED
                : (repaymentType == RepaymentStructureType.IOT_PAY_PER_USE
                    ? PricingType.PAY_PER_USE
                    : PricingType.FIXED_ANNUITY)),
        repaymentType = repaymentType ??
            (pricingType == PricingType.REVENUE_INDEXED
                ? RepaymentStructureType.REVENUE_INDEXED
                : (pricingType == PricingType.PAY_PER_USE
                    ? RepaymentStructureType.IOT_PAY_PER_USE
                    : RepaymentStructureType.FIXED_MONTHLY));

  int get fixedMonthlyCents => monthlyBaseCents;
  double? get revenueSharePct => revenueSharePercent;

  @override
  List<Object?> get props => [
        quoteId,
        qualificationStatus,
        pricingType,
        repaymentType,
        termMonths,
        requestedAmountCents,
        monthlyBaseCents,
        revenueSharePercent,
        estimatedMonthlyCents,
        floorCents,
        capCents,
        riskTier,
        estimatedUnderwriteSeconds,
        isOfflineEstimate,
        estimateFlag,
        options,
        expiresInSeconds,
      ];
}
