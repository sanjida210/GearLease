import 'package:equatable/equatable.dart';

class FleetSummary extends Equatable {
  final int totalAssetsCount;
  final int totalCapitalCommittedCents;
  final int nextAchDeductionCents;
  final DateTime nextAchDeductionDate;

  const FleetSummary({
    required this.totalAssetsCount,
    required this.totalCapitalCommittedCents,
    required this.nextAchDeductionCents,
    required this.nextAchDeductionDate,
  });

  @override
  List<Object?> get props => [
        totalAssetsCount,
        totalCapitalCommittedCents,
        nextAchDeductionCents,
        nextAchDeductionDate,
      ];
}
