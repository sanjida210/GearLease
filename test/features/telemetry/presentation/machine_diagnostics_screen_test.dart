import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/telemetry/domain/entities/machine_telemetry.dart';
import 'package:gearlease/features/telemetry/presentation/bloc/telemetry_bloc.dart';
import 'package:gearlease/features/telemetry/presentation/bloc/telemetry_event.dart';
import 'package:gearlease/features/telemetry/presentation/bloc/telemetry_state.dart';
import 'package:gearlease/features/telemetry/presentation/screens/machine_diagnostics_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockTelemetryBloc extends Mock implements TelemetryBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTelemetryBloc mockTelemetryBloc;

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

  setUpAll(() {
    registerFallbackValue(const TelemetrySubscribeRequested('ast_probat12'));
    registerFallbackValue(const TelemetryScheduleServiceRequested(assetId: 'ast_probat12'));
  });

  setUp(() {
    mockTelemetryBloc = MockTelemetryBloc();
    when(() => mockTelemetryBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget createWidgetUnderTest(TelemetryState state) {
    when(() => mockTelemetryBloc.state).thenReturn(state);

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: BlocProvider<TelemetryBloc>.value(
        value: mockTelemetryBloc,
        child: const MachineDiagnosticsScreen(assetId: 'ast_probat12'),
      ),
    );
  }

  group('MachineDiagnosticsScreen Widget Tests', () {
    testWidgets('renders machine details, metric tiles, and waveform chart', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        TelemetryStreaming(
          latest: testTelemetry,
          history: [testTelemetry],
        ),
      ));
      await tester.pump();

      expect(find.text('IOT MACHINE DIAGNOSTICS'), findsOneWidget);
      expect(find.text('Probat P12 Roaster'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);
      expect(find.text('MOTOR RPM'), findsOneWidget);
      expect(find.text('OPERATING TEMP'), findsOneWidget);
      expect(find.text('RUNNING HOURS'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('renders alert banner and schedules service on button tap', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        TelemetryStreaming(
          latest: testTelemetry,
          history: [testTelemetry],
        ),
      ));
      await tester.pump();

      expect(find.byKey(const Key('schedule_service_button')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('schedule_service_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('schedule_service_button')));
      await tester.pump();

      verify(() => mockTelemetryBloc.add(any(that: isA<TelemetryScheduleServiceRequested>()))).called(1);
    });

    testWidgets('renders CircularProgressIndicator when state is TelemetryLoading', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(TelemetryLoading()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
