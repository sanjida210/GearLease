import 'package:equatable/equatable.dart';
import '../../domain/entities/machine_telemetry.dart';

abstract class TelemetryState extends Equatable {
  const TelemetryState();

  @override
  List<Object?> get props => [];
}

class TelemetryInitial extends TelemetryState {}

class TelemetryLoading extends TelemetryState {}

class TelemetryStreaming extends TelemetryState {
  final MachineTelemetry? latest;
  final List<MachineTelemetry> history;
  final List<MachineTelemetry> fleet;
  final bool isBookingService;
  final bool serviceBookedSuccessfully;

  const TelemetryStreaming({
    this.latest,
    this.history = const [],
    this.fleet = const [],
    this.isBookingService = false,
    this.serviceBookedSuccessfully = false,
  });

  TelemetryStreaming copyWith({
    MachineTelemetry? latest,
    List<MachineTelemetry>? history,
    List<MachineTelemetry>? fleet,
    bool? isBookingService,
    bool? serviceBookedSuccessfully,
  }) {
    return TelemetryStreaming(
      latest: latest ?? this.latest,
      history: history ?? this.history,
      fleet: fleet ?? this.fleet,
      isBookingService: isBookingService ?? this.isBookingService,
      serviceBookedSuccessfully: serviceBookedSuccessfully ?? this.serviceBookedSuccessfully,
    );
  }

  @override
  List<Object?> get props => [
        latest,
        history,
        fleet,
        isBookingService,
        serviceBookedSuccessfully,
      ];
}

class TelemetryError extends TelemetryState {
  final String message;

  const TelemetryError(this.message);

  @override
  List<Object?> get props => [message];
}
