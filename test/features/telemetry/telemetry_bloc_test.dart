import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/utils/result.dart';
import 'package:gearlease/features/telemetry/domain/entities/machine_telemetry.dart';
import 'package:gearlease/features/telemetry/domain/entities/predictive_alert.dart';
import 'package:gearlease/features/telemetry/domain/repositories/telemetry_repository.dart';
import 'package:gearlease/features/telemetry/presentation/bloc/telemetry_bloc.dart';
import 'package:gearlease/features/telemetry/presentation/bloc/telemetry_event.dart';
import 'package:gearlease/features/telemetry/presentation/bloc/telemetry_state.dart';
import 'package:mocktail/mocktail.dart';

class MockTelemetryRepository extends Mock implements TelemetryRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTelemetryRepository mockRepository;
  late TelemetryBloc telemetryBloc;
  late StreamController<MachineTelemetry> testStreamController;

  final testTelemetry = MachineTelemetry(
    assetId: 'CAT-320D',
    machineName: 'CAT 320D Hydraulic Excavator',
    category: 'Heavy Equipment',
    runningHours: 1450.0,
    temperatureCelsius: 82.5,
    motorRpm: 1950.0,
    status: MachineStatus.warning,
    currentBillingCents: 145000,
    billingType: 'Revenue-Indexed',
    timestamp: DateTime.parse('2026-11-08T12:00:00Z'),
  );

  final testAlert = PredictiveAlert(
    alertId: 'alt-thermal-01',
    assetId: 'CAT-320D',
    severity: AlertSeverity.HIGH,
    title: 'High Thermal Drift',
    description: 'Operating temperature 82.5°C exceeds optimal threshold',
    suggestedAction: 'Inspect cooling loop and hydraulic fluid levels',
    timestamp: DateTime.parse('2026-11-08T12:00:00Z'),
  );

  setUp(() {
    mockRepository = MockTelemetryRepository();
    testStreamController = StreamController<MachineTelemetry>.broadcast();

    when(() => mockRepository.getActiveAlerts('CAT-320D'))
        .thenAnswer((_) async => Result.success([testAlert]));
    when(() => mockRepository.requestMaintenanceService(any(), any()))
        .thenAnswer((_) async => Result.success(null));
    when(() => mockRepository.watchMachineTelemetry('CAT-320D'))
        .thenAnswer((_) => testStreamController.stream);

    telemetryBloc = TelemetryBloc(telemetryRepository: mockRepository);
  });

  tearDown(() async {
    await telemetryBloc.close();
    await testStreamController.close();
  });

  group('Phase 20 — TelemetryBloc TDD Specification Tests', () {
    test('initial state is TelemetryInitial', () {
      expect(telemetryBloc.state, equals(TelemetryInitial()));
    });

    blocTest<TelemetryBloc, TelemetryState>(
      'StartTelemetryStream emits TelemetryConnecting, fetches active alerts, and streams TelemetryLive',
      build: () {
        when(() => mockRepository.watchMachineTelemetry('CAT-320D'))
            .thenAnswer((_) => Stream.value(testTelemetry));
        return telemetryBloc;
      },
      act: (bloc) => bloc.add(const StartTelemetryStream('CAT-320D')),
      expect: () => [
        isA<TelemetryConnecting>(),
        isA<TelemetryLive>()
            .having((s) => s.data.assetId, 'data.assetId', 'CAT-320D')
            .having((s) => s.alerts.length, 'alerts.length', 1)
            .having((s) => s.alerts.first.alertId, 'alerts.first.alertId', 'alt-thermal-01'),
      ],
      verify: (_) {
        verify(() => mockRepository.getActiveAlerts('CAT-320D')).called(1);
        verify(() => mockRepository.watchMachineTelemetry('CAT-320D')).called(1);
      },
    );

    blocTest<TelemetryBloc, TelemetryState>(
      'TelemetryUpdated updates data and appends to telemetry history',
      build: () => telemetryBloc,
      seed: () => TelemetryLive(
        testTelemetry,
        [testAlert],
        [testTelemetry],
      ),
      act: (bloc) {
        final update = MachineTelemetry(
          assetId: 'CAT-320D',
          machineName: 'CAT 320D Hydraulic Excavator',
          category: 'Heavy Equipment',
          runningHours: 1450.2,
          temperatureCelsius: 83.1,
          motorRpm: 1980.0,
          status: MachineStatus.warning,
          currentBillingCents: 145000,
          billingType: 'Revenue-Indexed',
          timestamp: DateTime.parse('2026-11-08T12:01:00Z'),
        );
        bloc.add(TelemetryUpdated(update));
      },
      expect: () => [
        isA<TelemetryLive>()
            .having((s) => s.data.temperatureCelsius, 'temperatureCelsius', 83.1)
            .having((s) => s.history.length, 'history.length', 2),
      ],
    );

    blocTest<TelemetryBloc, TelemetryState>(
      'AcknowledgeAlert removes acknowledged alert from active alerts list',
      build: () => telemetryBloc,
      seed: () => TelemetryLive(
        testTelemetry,
        [testAlert],
        [testTelemetry],
      ),
      act: (bloc) => bloc.add(const AcknowledgeAlert('alt-thermal-01')),
      expect: () => [
        isA<TelemetryLive>()
            .having((s) => s.alerts.isEmpty, 'alerts.isEmpty', isTrue),
      ],
    );

    blocTest<TelemetryBloc, TelemetryState>(
      'StopTelemetryStream cancels stream subscription and stops telemetry stream',
      build: () => telemetryBloc,
      act: (bloc) async {
        bloc.add(const StartTelemetryStream('CAT-320D'));
        await Future.delayed(const Duration(milliseconds: 20));
        bloc.add(const StopTelemetryStream());
      },
      verify: (bloc) {
        expect(bloc.state, isNot(isA<TelemetryFault>()));
      },
    );

    blocTest<TelemetryBloc, TelemetryState>(
      'emits TelemetryOffline with cached data when stream errors after initial data received',
      build: () => telemetryBloc,
      act: (bloc) async {
        bloc.add(const StartTelemetryStream('CAT-320D'));
        await Future.delayed(const Duration(milliseconds: 20));
        testStreamController.add(testTelemetry);
        await Future.delayed(const Duration(milliseconds: 20));
        testStreamController.addError(Exception('WebSocket link dropped'));
      },
      expect: () => [
        isA<TelemetryConnecting>(),
        isA<TelemetryLive>().having((s) => s.data.assetId, 'assetId', 'CAT-320D'),
        isA<TelemetryOffline>().having((s) => s.cachedData.assetId, 'cachedData.assetId', 'CAT-320D'),
      ],
    );

    blocTest<TelemetryBloc, TelemetryState>(
      'emits TelemetryFault when stream errors immediately without cached data',
      build: () {
        when(() => mockRepository.watchMachineTelemetry('CAT-320D'))
            .thenAnswer((_) => Stream.error(Exception('Connection refused')));
        return telemetryBloc;
      },
      act: (bloc) => bloc.add(const StartTelemetryStream('CAT-320D')),
      expect: () => [
        isA<TelemetryConnecting>(),
        isA<TelemetryFault>().having((s) => s.error, 'error', contains('Connection refused')),
      ],
    );

    test('auto-unsubscribes and closes cleanly when bloc is closed', () async {
      final controller = StreamController<MachineTelemetry>();
      when(() => mockRepository.watchMachineTelemetry('CAT-320D'))
          .thenAnswer((_) => controller.stream);

      telemetryBloc.add(const StartTelemetryStream('CAT-320D'));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(controller.hasListener, isTrue);

      await telemetryBloc.close();
      expect(controller.hasListener, isFalse);
    });
  });
}
