import '../../domain/entities/machine_telemetry.dart';

class MachineTelemetryModel extends MachineTelemetry {
  const MachineTelemetryModel({
    required super.assetId,
    required super.machineName,
    required super.category,
    required super.runningHours,
    required super.temperatureCelsius,
    required super.motorRpm,
    super.vibrationG,
    required super.status,
    required super.currentBillingCents,
    required super.billingType,
    required super.timestamp,
    super.lastHeartbeat,
  });

  factory MachineTelemetryModel.fromJson(Map<String, dynamic> json) {
    MachineStatus parseStatus(dynamic value) {
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower.contains('warn')) return MachineStatus.warning;
        if (lower.contains('fault') || lower.contains('crit') || lower.contains('err')) {
          return MachineStatus.fault;
        }
      }
      return MachineStatus.optimal;
    }

    return MachineTelemetryModel(
      assetId: json['asset_id'] as String? ?? json['assetId'] as String? ?? '',
      machineName: json['machine_name'] as String? ?? json['machineName'] as String? ?? 'Commercial Equipment',
      category: json['category'] as String? ?? 'Heavy Equipment',
      runningHours: (json['running_hours'] as num? ?? json['runningHours'] as num? ?? json['hours'] as num? ?? 0.0).toDouble(),
      temperatureCelsius: (json['temperature_celsius'] as num? ?? json['temperatureCelsius'] as num? ?? json['temp_celsius'] as num? ?? 0.0).toDouble(),
      motorRpm: (json['motor_rpm'] as num? ?? json['motorRpm'] as num? ?? json['rpm'] as num? ?? 0.0).toDouble(),
      vibrationG: (json['vibration_g'] as num? ?? json['vibrationG'] as num? ?? 0.0).toDouble(),
      status: parseStatus(json['status']),
      currentBillingCents: (json['current_billing_cents'] as num? ?? json['currentBillingCents'] as num? ?? 0).toInt(),
      billingType: json['billing_type'] as String? ?? json['billingType'] as String? ?? 'Fixed Lease',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : (json['recorded_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['recorded_at'] as int)
              : DateTime.now()),
      lastHeartbeat: json['last_heartbeat'] != null
          ? DateTime.tryParse(json['last_heartbeat'] as String)
          : null,
    );
  }

  factory MachineTelemetryModel.fromDbMap(Map<String, dynamic> map, {
    String? machineName,
    String? category,
    String? billingType,
    int? currentBillingCents,
  }) {
    final temp = (map['temp_celsius'] as num? ?? 0.0).toDouble();
    final status = temp >= 85.0
        ? MachineStatus.fault
        : (temp >= 75.0 ? MachineStatus.warning : MachineStatus.optimal);

    return MachineTelemetryModel(
      assetId: map['asset_id'] as String? ?? '',
      machineName: machineName ?? 'Probat P12 Roaster',
      category: category ?? 'Commercial Kitchen',
      runningHours: (map['hours'] as num? ?? 0.0).toDouble(),
      temperatureCelsius: temp,
      motorRpm: (map['rpm'] as num? ?? 0.0).toDouble(),
      status: status,
      currentBillingCents: currentBillingCents ?? 112000,
      billingType: billingType ?? 'Revenue-Indexed',
      timestamp: map['recorded_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['recorded_at'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'asset_id': assetId,
      'machine_name': machineName,
      'category': category,
      'running_hours': runningHours,
      'temperature_celsius': temperatureCelsius,
      'motor_rpm': motorRpm,
      'status': status.name,
      'current_billing_cents': currentBillingCents,
      'billing_type': billingType,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      'asset_id': assetId,
      'rpm': motorRpm,
      'temp_celsius': temperatureCelsius,
      'hours': runningHours,
      'recorded_at': timestamp.millisecondsSinceEpoch,
    };
  }
}
