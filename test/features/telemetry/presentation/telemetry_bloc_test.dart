import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
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
      'subscribes to machine stream and emits TelemetryLoading then TelemetryStreaming',
      build: () {
        when(() => mockRepository.watchMachineTelemetry('ast_probat12'))
            .thenAnswer((_) => Stream.value(testTelemetry));
        return telemetryBloc;
      },
      act: (bloc) => bloc.add(const TelemetrySubscribeRequested('ast_probat12')),
      expect: () => [
        TelemetryLoading(),
        TelemetryStreaming(
          latest: testTelemetry,
          history: [testTelemetry],
        ),
      ],
    );

    blocTest<TelemetryBloc, TelemetryState>(
      'subscribes to fleet stream and emits TelemetryLoading then TelemetryStreaming with fleet',
      build: () {
        when(() => mockRepository.watchFleetTelemetry())
            .thenAnswer((_) => Stream.value([testTelemetry]));
        return telemetryBloc;
      },
      act: (bloc) => bloc.add(TelemetryFleetSubscribeRequested()),
      expect: () => [
        TelemetryLoading(),
        TelemetryStreaming(
          fleet: [testTelemetry],
          latest: testTelemetry,
          history: [testTelemetry],
        ),
      ],
    );

    blocTest<TelemetryBloc, TelemetryState>(
      'emits updated history on consecutive TelemetryDataUpdated events',
      build: () => telemetryBloc,
      seed: () => TelemetryStreaming(
        latest: testTelemetry,
        history: [testTelemetry],
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
        bloc.add(TelemetryDataUpdated(update));
      },
      verify: (bloc) {
        final state = bloc.state as TelemetryStreaming;
        expect(state.history.length, 2);
        expect(state.latest?.temperatureCelsius, 79.5);
      },
    );

    blocTest<TelemetryBloc, TelemetryState>(
      'handles TelemetryScheduleServiceRequested and sets serviceBookedSuccessfully',
      build: () {
        when(() => mockRepository.scheduleWarrantyService(any(), any()))
            .thenAnswer((_) async => true);
        return telemetryBloc;
      },
      seed: () => TelemetryStreaming(
        latest: testTelemetry,
        history: [testTelemetry],
      ),
      act: (bloc) => bloc.add(const TelemetryScheduleServiceRequested(
        assetId: 'ast_probat12',
        notes: 'High temp alert',
      )),
      expect: () => [
        TelemetryStreaming(
          latest: testTelemetry,
          history: [testTelemetry],
          isBookingService: true,
          serviceBookedSuccessfully: false,
        ),
        TelemetryStreaming(
          latest: testTelemetry,
          history: [testTelemetry],
          isBookingService: false,
          serviceBookedSuccessfully: true,
        ),
      ],
    );
  });
}
