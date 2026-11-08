import 'package:equatable/equatable.dart';

// ignore_for_file: constant_identifier_names

enum RepaymentStructureType {
  FIXED_MONTHLY,
  REVENUE_INDEXED,
  IOT_PAY_PER_USE,
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
  final String quoteId;
  final QualificationStatus qualificationStatus;
  final RepaymentStructureType repaymentType;
  final int termMonths;
  final int requestedAmountCents;
  final int fixedMonthlyCents;
  final double? revenueSharePct;
  final int? estimatedMonthlyCents;
  final int? floorCents;
  final int? capCents;
  final List<QuoteOption> options;
  final int expiresInSeconds;

  const QuoteCalculation({
    required this.quoteId,
    required this.qualificationStatus,
    required this.repaymentType,
    required this.termMonths,
    required this.requestedAmountCents,
    required this.fixedMonthlyCents,
    this.revenueSharePct,
    this.estimatedMonthlyCents,
    this.floorCents,
    this.capCents,
    this.options = const [],
    this.expiresInSeconds = 900,
  });

  @override
  List<Object?> get props => [
        quoteId,
        qualificationStatus,
        repaymentType,
        termMonths,
        requestedAmountCents,
        fixedMonthlyCents,
        revenueSharePct,
        estimatedMonthlyCents,
        floorCents,
        capCents,
        options,
        expiresInSeconds,
      ];
}
