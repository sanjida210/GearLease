import 'package:equatable/equatable.dart';

enum RepaymentStructureType { fixedMonthly, revenueIndexed, iotPayPerUse }

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
  final String qualificationStatus;
  final int termMonths;
  final List<QuoteOption> options;
  final int expiresInSeconds;

  const QuoteCalculation({
    required this.quoteId,
    required this.qualificationStatus,
    required this.termMonths,
    required this.options,
    required this.expiresInSeconds,
  });

  @override
  List<Object?> get props => [
        quoteId,
        qualificationStatus,
        termMonths,
        options,
        expiresInSeconds,
      ];
}
