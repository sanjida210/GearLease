import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/machine_telemetry.dart';
import '../../domain/entities/predictive_alert.dart';
import '../../domain/repositories/telemetry_repository.dart';
import 'telemetry_event.dart';
import 'telemetry_state.dart';

class TelemetryBloc extends Bloc<TelemetryEvent, TelemetryState> {
  final TelemetryRepository telemetryRepository;
  StreamSubscription<MachineTelemetry>? _machineSubscription;
  StreamSubscription<List<MachineTelemetry>>? _fleetSubscription;
  MachineTelemetry? _lastTelemetry;
  List<PredictiveAlert> _activeAlerts = [];

  TelemetryBloc({
    required this.telemetryRepository,
  }) : super(TelemetryInitial()) {
    on<StartTelemetryStream>(_onStartTelemetryStream);
    on<TelemetryUpdated>(_onTelemetryUpdated);
    on<StopTelemetryStream>(_onStopTelemetryStream);
    on<AcknowledgeAlert>(_onAcknowledgeAlert);
    on<TelemetryFleetSubscribeRequested>(_onFleetSubscribeRequested);
    on<TelemetryFleetUpdated>(_onFleetUpdated);
    on<TelemetryScheduleServiceRequested>(_onScheduleServiceRequested);
    on<_TelemetryStreamFailed>(_onStreamFailed);
  }

  Future<void> _onStartTelemetryStream(
    StartTelemetryStream event,
    Emitter<TelemetryState> emit,
  ) async {
    emit(TelemetryConnecting());
    await _machineSubscription?.cancel();
    _machineSubscription = null;

    // Fetch active predictive alerts for the machine
    try {
      final alertsResult = await telemetryRepository.getActiveAlerts(event.assetId);
      _activeAlerts = alertsResult.isSuccess ? (alertsResult.dataOrNull ?? []) : [];
    } catch (_) {
      _activeAlerts = [];
    }

    _machineSubscription = telemetryRepository
        .watchMachineTelemetry(event.assetId)
        .listen(
          (telemetry) => add(TelemetryUpdated(telemetry)),
          onError: (err) => add(_TelemetryStreamFailed(err.toString())),
          cancelOnError: false,
        );
  }

  void _onTelemetryUpdated(
    TelemetryUpdated event,
    Emitter<TelemetryState> emit,
  ) {
    _lastTelemetry = event.telemetry;

    final history = <MachineTelemetry>[];
    if (state is TelemetryLive) {
      final current = state as TelemetryLive;
      history.addAll(current.history);
    }
    history.add(event.telemetry);
    if (history.length > 20) {
      history.removeAt(0);
    }

    emit(TelemetryLive(
      event.telemetry,
      _activeAlerts,
      history,
    ));
  }

  Future<void> _onStopTelemetryStream(
    StopTelemetryStream event,
    Emitter<TelemetryState> emit,
  ) async {
    await _machineSubscription?.cancel();
    _machineSubscription = null;
  }

  void _onAcknowledgeAlert(
    AcknowledgeAlert event,
    Emitter<TelemetryState> emit,
  ) {
    _activeAlerts = _activeAlerts.where((a) => a.alertId != event.alertId).toList();

    if (state is TelemetryLive) {
      final current = state as TelemetryLive;
      emit(current.copyWith(alerts: _activeAlerts));
    } else if (state is TelemetryOffline) {
      final current = state as TelemetryOffline;
      emit(TelemetryOffline(current.cachedData, _activeAlerts));
    }
  }

  void _onStreamFailed(
    _TelemetryStreamFailed event,
    Emitter<TelemetryState> emit,
  ) {
    if (_lastTelemetry != null) {
      emit(TelemetryOffline(_lastTelemetry!, _activeAlerts));
    } else {
      emit(TelemetryFault(event.error));
    }
  }

  Future<void> _onFleetSubscribeRequested(
    TelemetryFleetSubscribeRequested event,
    Emitter<TelemetryState> emit,
  ) async {
    emit(TelemetryConnecting());
    await _fleetSubscription?.cancel();
    _fleetSubscription = telemetryRepository.watchFleetTelemetry().listen(
          (fleet) => add(TelemetryFleetUpdated(fleet)),
          onError: (err) => emit(TelemetryFault(err.toString())),
        );
  }

  void _onFleetUpdated(
    TelemetryFleetUpdated event,
    Emitter<TelemetryState> emit,
  ) {
    if (state is TelemetryLive) {
      final current = state as TelemetryLive;
      emit(current.copyWith(fleet: event.fleet));
    } else {
      final primary = event.fleet.isNotEmpty
          ? event.fleet.first
          : const MachineTelemetry(
              assetId: '',
              temperatureCelsius: 0,
              status: MachineStatus.optimal,
            );
      emit(TelemetryLive(
        primary,
        _activeAlerts,
        event.fleet.isNotEmpty ? [event.fleet.first] : const [],
        event.fleet,
      ));
    }
  }

  Future<void> _onScheduleServiceRequested(
    TelemetryScheduleServiceRequested event,
    Emitter<TelemetryState> emit,
  ) async {
    if (state is TelemetryLive) {
      final current = state as TelemetryLive;
      emit(current.copyWith(isBookingService: true));

      final success = await telemetryRepository.scheduleWarrantyService(
        event.assetId,
        event.notes,
      );

      emit(current.copyWith(
        isBookingService: false,
        serviceBookedSuccessfully: success,
      ));
    }
  }

  @override
  Future<void> close() async {
    await _machineSubscription?.cancel();
    _machineSubscription = null;
    await _fleetSubscription?.cancel();
    _fleetSubscription = null;
    return super.close();
  }
}

class _TelemetryStreamFailed extends TelemetryEvent {
  final String error;

  const _TelemetryStreamFailed(this.error);

  @override
  List<Object?> get props => [error];
}
