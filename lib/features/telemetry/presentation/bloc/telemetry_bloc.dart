import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/telemetry_repository.dart';
import 'telemetry_event.dart';
import 'telemetry_state.dart';

class TelemetryBloc extends Bloc<TelemetryEvent, TelemetryState> {
  final TelemetryRepository telemetryRepository;
  StreamSubscription? _machineSubscription;
  StreamSubscription? _fleetSubscription;

  TelemetryBloc({
    required this.telemetryRepository,
  }) : super(TelemetryInitial()) {
    on<TelemetrySubscribeRequested>(_onSubscribeRequested);
    on<TelemetryDataUpdated>(_onDataUpdated);
    on<TelemetryFleetSubscribeRequested>(_onFleetSubscribeRequested);
    on<TelemetryFleetUpdated>(_onFleetUpdated);
    on<TelemetryScheduleServiceRequested>(_onScheduleServiceRequested);
  }

  Future<void> _onSubscribeRequested(
    TelemetrySubscribeRequested event,
    Emitter<TelemetryState> emit,
  ) async {
    emit(TelemetryLoading());
    await _machineSubscription?.cancel();
    _machineSubscription = telemetryRepository
        .watchMachineTelemetry(event.assetId)
        .listen(
          (telemetry) => add(TelemetryDataUpdated(telemetry)),
          onError: (err) => emit(TelemetryError(err.toString())),
        );
  }

  void _onDataUpdated(
    TelemetryDataUpdated event,
    Emitter<TelemetryState> emit,
  ) {
    if (state is TelemetryStreaming) {
      final current = state as TelemetryStreaming;
      final newHistory = [...current.history, event.telemetry];
      if (newHistory.length > 20) {
        newHistory.removeAt(0);
      }
      emit(current.copyWith(
        latest: event.telemetry,
        history: newHistory,
      ));
    } else {
      emit(TelemetryStreaming(
        latest: event.telemetry,
        history: [event.telemetry],
      ));
    }
  }

  Future<void> _onFleetSubscribeRequested(
    TelemetryFleetSubscribeRequested event,
    Emitter<TelemetryState> emit,
  ) async {
    emit(TelemetryLoading());
    await _fleetSubscription?.cancel();
    _fleetSubscription = telemetryRepository.watchFleetTelemetry().listen(
          (fleet) => add(TelemetryFleetUpdated(fleet)),
          onError: (err) => emit(TelemetryError(err.toString())),
        );
  }

  void _onFleetUpdated(
    TelemetryFleetUpdated event,
    Emitter<TelemetryState> emit,
  ) {
    if (state is TelemetryStreaming) {
      final current = state as TelemetryStreaming;
      emit(current.copyWith(fleet: event.fleet));
    } else {
      emit(TelemetryStreaming(
        fleet: event.fleet,
        latest: event.fleet.isNotEmpty ? event.fleet.first : null,
        history: event.fleet.isNotEmpty ? [event.fleet.first] : const [],
      ));
    }
  }

  Future<void> _onScheduleServiceRequested(
    TelemetryScheduleServiceRequested event,
    Emitter<TelemetryState> emit,
  ) async {
    if (state is TelemetryStreaming) {
      final current = state as TelemetryStreaming;
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
  Future<void> close() {
    _machineSubscription?.cancel();
    _fleetSubscription?.cancel();
    return super.close();
  }
}
