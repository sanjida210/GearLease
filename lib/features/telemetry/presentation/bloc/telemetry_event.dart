import 'package:equatable/equatable.dart';
import '../../domain/entities/machine_telemetry.dart';

abstract class TelemetryEvent extends Equatable {
  const TelemetryEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to initiate real-time machine telematics streaming.
class StartTelemetryStream extends TelemetryEvent {
  final String assetId;

  const StartTelemetryStream(this.assetId);

  @override
  List<Object?> get props => [assetId];
}

/// Dispatched when new telemetry data packet arrives from IoT broker.
class TelemetryUpdated extends TelemetryEvent {
  final MachineTelemetry telemetry;

  const TelemetryUpdated(this.telemetry);

  @override
  List<Object?> get props => [telemetry];
}

/// Dispatched to stop and auto-unsubscribe from telematics stream.
class StopTelemetryStream extends TelemetryEvent {
  const StopTelemetryStream();
}

/// Dispatched when user acknowledges an active predictive alert.
class AcknowledgeAlert extends TelemetryEvent {
  final String alertId;

  const AcknowledgeAlert(this.alertId);

  @override
  List<Object?> get props => [alertId];
}

// --- Backward Compatibility Aliases & Secondary Events ---

typedef TelemetrySubscribeRequested = StartTelemetryStream;
typedef TelemetryDataUpdated = TelemetryUpdated;

class TelemetryFleetSubscribeRequested extends TelemetryEvent {}

class TelemetryFleetUpdated extends TelemetryEvent {
  final List<MachineTelemetry> fleet;

  const TelemetryFleetUpdated(this.fleet);

  @override
  List<Object?> get props => [fleet];
}

class TelemetryScheduleServiceRequested extends TelemetryEvent {
  final String assetId;
  final String notes;

  const TelemetryScheduleServiceRequested({
    required this.assetId,
    this.notes = 'Covered warranty maintenance requested from diagnostics screen',
  });

  @override
  List<Object?> get props => [assetId, notes];
}
