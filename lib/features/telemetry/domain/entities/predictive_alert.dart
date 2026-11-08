import 'package:equatable/equatable.dart';

// ignore_for_file: constant_identifier_names

enum AlertSeverity {
  LOW,
  MEDIUM,
  HIGH,
  CRITICAL;

  static AlertSeverity fromString(String? value) {
    if (value == null) return AlertSeverity.LOW;
    final upper = value.toUpperCase();
    for (final s in AlertSeverity.values) {
      if (s.name == upper) return s;
    }
    return AlertSeverity.LOW;
  }
}

class PredictiveAlert extends Equatable {
  final String alertId;
  final String assetId;
  final AlertSeverity severity;
  final String title;
  final String description;
  final String suggestedAction;
  final DateTime timestamp;

  const PredictiveAlert({
    required this.alertId,
    required this.assetId,
    required this.severity,
    required this.title,
    required this.description,
    required this.suggestedAction,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [
        alertId,
        assetId,
        severity,
        title,
        description,
        suggestedAction,
        timestamp,
      ];
}
