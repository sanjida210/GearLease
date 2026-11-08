import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/utils/result.dart';
import 'package:gearlease/features/telemetry/domain/entities/machine_telemetry.dart';
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

  final testTelemetry = MachineTelemetry(
    assetId: 'ast_probat12',
    machineName: 'Probat P12 Roaster',
    category: 'Commercial Kitchen',
    runningHours: 1248.5,
    temperatureCelsius: 78.0,
    motorRpm: 1420.0,
    status: MachineStatus.warning,
    currentBillingCents: 112000,
    billingType: 'Revenue-Indexed',
    timestamp: DateTime.parse('2026-11-04T10:30:00Z'),
  );

  setUp(() {
    mockRepository = MockTelemetryRepository();
    telemetryBloc = TelemetryBloc(telemetryRepository: mockRepository);
  });

  tearDown(() {
    telemetryBloc.close();
  });

  group('TelemetryBloc Tests', () {
    test('initial state is TelemetryInitial', () {
      expect(telemetryBloc.state, equals(TelemetryInitial()));
    });

    blocTest<TelemetryBloc, TelemetryState>(
      'subscribes to machine stream and emits TelemetryConnecting then TelemetryLive',
      build: () {
        when(() => mockRepository.getActiveAlerts('ast_probat12'))
            .thenAnswer((_) async => Result.success(const []));
        when(() => mockRepository.watchMachineTelemetry('ast_probat12'))
            .thenAnswer((_) => Stream.value(testTelemetry));
        return telemetryBloc;
      },
      act: (bloc) => bloc.add(const StartTelemetryStream('ast_probat12')),
      expect: () => [
        isA<TelemetryConnecting>(),
        isA<TelemetryLive>()
            .having((s) => s.data.assetId, 'data.assetId', 'ast_probat12')
            .having((s) => s.history.length, 'history.length', 1),
      ],
    );

    blocTest<TelemetryBloc, TelemetryState>(
      'subscribes to fleet stream and emits TelemetryConnecting then TelemetryLive with fleet',
      build: () {
        when(() => mockRepository.watchFleetTelemetry())
            .thenAnswer((_) => Stream.value([testTelemetry]));
        return telemetryBloc;
      },
      act: (bloc) => bloc.add(TelemetryFleetSubscribeRequested()),
      expect: () => [
        isA<TelemetryConnecting>(),
        isA<TelemetryLive>()
            .having((s) => s.fleet.length, 'fleet.length', 1)
            .having((s) => s.data.assetId, 'data.assetId', 'ast_probat12'),
      ],
    );

    blocTest<TelemetryBloc, TelemetryState>(
      'emits updated history on consecutive TelemetryDataUpdated events',
      build: () => telemetryBloc,
      seed: () => TelemetryLive(
        testTelemetry,
        const [],
        [testTelemetry],
      ),
      act: (bloc) {
        final update = MachineTelemetry(
          assetId: 'ast_probat12',
          machineName: 'Probat P12 Roaster',
          category: 'Commercial Kitchen',
          runningHours: 1249.0,
          temperatureCelsius: 79.5,
          motorRpm: 1425.0,
          status: MachineStatus.warning,
          currentBillingCents: 112000,
          billingType: 'Revenue-Indexed',
          timestamp: DateTime.parse('2026-11-04T10:31:00Z'),
        );
        bloc.add(TelemetryUpdated(update));
      },
      verify: (bloc) {
        final state = bloc.state as TelemetryLive;
        expect(state.history.length, 2);
        expect(state.latest.temperatureCelsius, 79.5);
      },
    );

    blocTest<TelemetryBloc, TelemetryState>(
      'handles TelemetryScheduleServiceRequested and sets serviceBookedSuccessfully',
      build: () {
        when(() => mockRepository.scheduleWarrantyService(any(), any()))
            .thenAnswer((_) async => true);
        return telemetryBloc;
      },
      seed: () => TelemetryLive(
        testTelemetry,
        const [],
        [testTelemetry],
      ),
      act: (bloc) => bloc.add(const TelemetryScheduleServiceRequested(
        assetId: 'ast_probat12',
        notes: 'High temp alert',
      )),
      expect: () => [
        isA<TelemetryLive>()
            .having((s) => s.isBookingService, 'isBookingService', true)
            .having((s) => s.serviceBookedSuccessfully, 'serviceBookedSuccessfully', false),
        isA<TelemetryLive>()
            .having((s) => s.isBookingService, 'isBookingService', false)
            .having((s) => s.serviceBookedSuccessfully, 'serviceBookedSuccessfully', true),
      ],
    );
  });
}
