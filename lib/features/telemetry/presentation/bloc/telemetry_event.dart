import 'package:equatable/equatable.dart';
import '../../domain/entities/machine_telemetry.dart';

abstract class TelemetryEvent extends Equatable {
  const TelemetryEvent();

  @override
  List<Object?> get props => [];
}

class TelemetrySubscribeRequested extends TelemetryEvent {
  final String assetId;

  const TelemetrySubscribeRequested(this.assetId);

  @override
  List<Object?> get props => [assetId];
}

class TelemetryDataUpdated extends TelemetryEvent {
  final MachineTelemetry telemetry;

  const TelemetryDataUpdated(this.telemetry);

  @override
  List<Object?> get props => [telemetry];
}

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
