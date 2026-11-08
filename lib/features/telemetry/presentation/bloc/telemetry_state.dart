import 'package:equatable/equatable.dart';
import '../../domain/entities/machine_telemetry.dart';
import '../../domain/entities/predictive_alert.dart';

abstract class TelemetryState extends Equatable {
  const TelemetryState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any telematics connection.
class TelemetryInitial extends TelemetryState {}

/// State while WebSocket handshake or broker connection is in progress.
class TelemetryConnecting extends TelemetryState {}

/// State when live telemetry is actively streaming.
class TelemetryLive extends TelemetryState {
  final MachineTelemetry data;
  final List<PredictiveAlert> alerts;
  final List<MachineTelemetry> history;
  final List<MachineTelemetry> fleet;
  final bool isBookingService;
  final bool serviceBookedSuccessfully;

  const TelemetryLive(
    this.data, [
    this.alerts = const [],
    this.history = const [],
    this.fleet = const [],
    this.isBookingService = false,
    this.serviceBookedSuccessfully = false,
  ]);

  const TelemetryLive.named({
    required this.data,
    this.alerts = const [],
    this.history = const [],
    this.fleet = const [],
    this.isBookingService = false,
    this.serviceBookedSuccessfully = false,
  });

  MachineTelemetry get latest => data;

  TelemetryLive copyWith({
    MachineTelemetry? data,
    List<PredictiveAlert>? alerts,
    List<MachineTelemetry>? history,
    List<MachineTelemetry>? fleet,
    bool? isBookingService,
    bool? serviceBookedSuccessfully,
  }) {
    return TelemetryLive(
      data ?? this.data,
      alerts ?? this.alerts,
      history ?? this.history,
      fleet ?? this.fleet,
      isBookingService ?? this.isBookingService,
      serviceBookedSuccessfully ?? this.serviceBookedSuccessfully,
    );
  }

  @override
  List<Object?> get props => [
        data,
        alerts,
        history,
        fleet,
        isBookingService,
        serviceBookedSuccessfully,
      ];
}

/// State when live streaming drops and cached SQLite data is displayed.
class TelemetryOffline extends TelemetryState {
  final MachineTelemetry cachedData;
  final List<PredictiveAlert> alerts;

  const TelemetryOffline(
    this.cachedData, [
    this.alerts = const [],
  ]);

  MachineTelemetry get latest => cachedData;

  @override
  List<Object?> get props => [cachedData, alerts];
}

/// State when an unrecoverable telemetry or network error occurs.
class TelemetryFault extends TelemetryState {
  final String error;

  const TelemetryFault(this.error);

  String get message => error;

  @override
  List<Object?> get props => [error];
}

// --- Backward Compatibility Aliases & Adapters ---

typedef TelemetryLoading = TelemetryConnecting;
typedef TelemetryError = TelemetryFault;

class TelemetryStreaming extends TelemetryLive {
  TelemetryStreaming({
    MachineTelemetry? data,
    MachineTelemetry? latest,
    List<PredictiveAlert> alerts = const [],
    List<MachineTelemetry> history = const [],
    List<MachineTelemetry> fleet = const [],
    bool isBookingService = false,
    bool serviceBookedSuccessfully = false,
  }) : super(
          data ??
              latest ??
              (fleet.isNotEmpty
                  ? fleet.first
                  : const MachineTelemetry(
                      assetId: '',
                      temperatureCelsius: 0,
                      status: MachineStatus.optimal,
                    )),
          alerts,
          history,
          fleet,
          isBookingService,
          serviceBookedSuccessfully,
        );
}
