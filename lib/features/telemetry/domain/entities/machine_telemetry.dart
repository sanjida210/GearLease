import 'package:equatable/equatable.dart';

// ignore_for_file: constant_identifier_names

enum MachineStatus {
  optimal,
  warning,
  fault;

  static const MachineStatus OPTIMAL = MachineStatus.optimal;
  static const MachineStatus WARNING = MachineStatus.warning;
  static const MachineStatus CRITICAL = MachineStatus.fault;
}

typedef TelemetryStatus = MachineStatus;

class MachineTelemetry extends Equatable {
  final String assetId;
  final String machineName;
  final String category;
  final double operatingHours;
  final double temperatureCelsius;
  final double rpm;
  final double vibrationG;
  final MachineStatus status;
  final int currentBillingCents;
  final String billingType;
  final DateTime? recordedHeartbeat;
  final DateTime? recordedTimestamp;

  const MachineTelemetry({
    required this.assetId,
    this.machineName = 'Commercial Equipment',
    this.category = 'Heavy Equipment',
    double? operatingHours,
    double? runningHours,
    required this.temperatureCelsius,
    double? rpm,
    double? motorRpm,
    this.vibrationG = 0.0,
    required this.status,
    this.currentBillingCents = 0,
    this.billingType = 'Fixed Lease',
    DateTime? lastHeartbeat,
    DateTime? timestamp,
  })  : operatingHours = operatingHours ?? runningHours ?? 0.0,
        rpm = rpm ?? motorRpm ?? 0.0,
        recordedHeartbeat = lastHeartbeat,
        recordedTimestamp = timestamp;

  double get motorRpm => rpm;
  double get runningHours => operatingHours;
  DateTime get lastHeartbeat =>
      recordedHeartbeat ?? recordedTimestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
  DateTime get timestamp =>
      recordedTimestamp ?? recordedHeartbeat ?? DateTime.fromMillisecondsSinceEpoch(0);

  bool get hasAlert => status != MachineStatus.optimal || temperatureCelsius >= 75.0;

  @override
  List<Object?> get props => [
        assetId,
        machineName,
        category,
        operatingHours,
        temperatureCelsius,
        rpm,
        vibrationG,
        status,
        currentBillingCents,
        billingType,
        lastHeartbeat,
      ];
}
