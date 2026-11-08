import '../../domain/entities/quote_calculation.dart';

class QuoteOptionModel extends QuoteOption {
  const QuoteOptionModel({
    required super.model,
    super.fixedMonthlyCents,
    super.revenueSharePct,
    super.estimatedMonthlyCents,
    super.floorCents,
    super.capCents,
  });

  factory QuoteOptionModel.fromJson(Map<String, dynamic> json) {
    final modelStr = (json['model'] as String? ?? '').toUpperCase();
    RepaymentStructureType modelType;
    if (modelStr.contains('REV')) {
      modelType = RepaymentStructureType.REVENUE_INDEXED;
    } else if (modelStr.contains('IOT')) {
      modelType = RepaymentStructureType.IOT_PAY_PER_USE;
    } else {
      modelType = RepaymentStructureType.FIXED_MONTHLY;
    }

    return QuoteOptionModel(
      model: modelType,
      fixedMonthlyCents: (json['fixed_monthly_cents'] as num?)?.toInt(),
      revenueSharePct: (json['revenue_share_pct'] as num?)?.toDouble(),
      estimatedMonthlyCents: (json['estimated_monthly_cents'] as num?)?.toInt(),
      floorCents: (json['floor_cents'] as num?)?.toInt(),
      capCents: (json['cap_cents'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model': model.name,
      'fixed_monthly_cents': fixedMonthlyCents,
      'revenue_share_pct': revenueSharePct,
      'estimated_monthly_cents': estimatedMonthlyCents,
      'floor_cents': floorCents,
      'cap_cents': capCents,
    };
  }
}

class QuoteCalculationModel extends QuoteCalculation {
  const QuoteCalculationModel({
    required super.quoteId,
    required super.qualificationStatus,
    required super.repaymentType,
    required super.termMonths,
    required super.requestedAmountCents,
    required super.fixedMonthlyCents,
    super.revenueSharePct,
    super.estimatedMonthlyCents,
    super.floorCents,
    super.capCents,
    super.options = const [],
    super.expiresInSeconds = 900,
  });

  factory QuoteCalculationModel.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['qualification_status'] as String? ?? '').toUpperCase();
    QualificationStatus status;
    if (statusStr.contains('DECLINE')) {
      status = QualificationStatus.DECLINED;
    } else if (statusStr.contains('MANUAL') || statusStr.contains('REVIEW')) {
      status = QualificationStatus.REQUIRES_MANUAL_REVIEW;
    } else {
      status = QualificationStatus.INSTANT_QUALIFIED;
    }

    final typeStr = (json['repayment_type'] as String? ??
            json['pricing_model_requested'] as String? ??
            '')
        .toUpperCase();
    RepaymentStructureType repaymentType;
    if (typeStr.contains('REV')) {
      repaymentType = RepaymentStructureType.REVENUE_INDEXED;
    } else if (typeStr.contains('IOT')) {
      repaymentType = RepaymentStructureType.IOT_PAY_PER_USE;
    } else {
      repaymentType = RepaymentStructureType.FIXED_MONTHLY;
    }

    List<QuoteOption> options = [];
    if (json['options'] is List) {
      options = (json['options'] as List)
          .map((item) => QuoteOptionModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    return QuoteCalculationModel(
      quoteId: json['quote_id'] as String? ?? json['quoteId'] as String? ?? '',
      qualificationStatus: status,
      repaymentType: repaymentType,
      termMonths: (json['term_months'] as num?)?.toInt() ??
          (json['requested_term_months'] as num?)?.toInt() ??
          36,
      requestedAmountCents: (json['requested_amount_cents'] as num?)?.toInt() ??
          (json['invoice_amount_cents'] as num?)?.toInt() ??
          0,
      fixedMonthlyCents: (json['fixed_monthly_cents'] as num?)?.toInt() ?? 0,
      revenueSharePct: (json['revenue_share_pct'] as num?)?.toDouble(),
      estimatedMonthlyCents: (json['estimated_monthly_cents'] as num?)?.toInt(),
      floorCents: (json['floor_cents'] as num?)?.toInt(),
      capCents: (json['cap_cents'] as num?)?.toInt(),
      options: options,
      expiresInSeconds: (json['expires_in_seconds'] as num?)?.toInt() ?? 900,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quote_id': quoteId,
      'qualification_status': qualificationStatus.name,
      'repayment_type': repaymentType.name,
      'term_months': termMonths,
      'requested_amount_cents': requestedAmountCents,
      'fixed_monthly_cents': fixedMonthlyCents,
      'revenue_share_pct': revenueSharePct,
      'estimated_monthly_cents': estimatedMonthlyCents,
      'floor_cents': floorCents,
      'cap_cents': capCents,
      'options': options
          .map((opt) => opt is QuoteOptionModel
              ? opt.toJson()
              : QuoteOptionModel(
                  model: opt.model,
                  fixedMonthlyCents: opt.fixedMonthlyCents,
                  revenueSharePct: opt.revenueSharePct,
                  estimatedMonthlyCents: opt.estimatedMonthlyCents,
                  floorCents: opt.floorCents,
                  capCents: opt.capCents,
                ).toJson())
          .toList(),
      'expires_in_seconds': expiresInSeconds,
    };
  }
}
