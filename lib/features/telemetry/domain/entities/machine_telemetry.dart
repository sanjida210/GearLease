import 'package:equatable/equatable.dart';

enum MachineStatus { optimal, warning, fault }

class MachineTelemetry extends Equatable {
  final String assetId;
  final String machineName;
  final String category;
  final double runningHours;
  final double temperatureCelsius;
  final double motorRpm;
  final MachineStatus status;
  final int currentBillingCents;
  final String billingType;
  final DateTime timestamp;

  const MachineTelemetry({
    required this.assetId,
    required this.machineName,
    required this.category,
    required this.runningHours,
    required this.temperatureCelsius,
    required this.motorRpm,
    required this.status,
    required this.currentBillingCents,
    required this.billingType,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [
        assetId,
        machineName,
        category,
        runningHours,
        temperatureCelsius,
        motorRpm,
        status,
        currentBillingCents,
        billingType,
        timestamp,
      ];
}
