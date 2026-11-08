import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/telemetry/domain/entities/machine_telemetry.dart';
import 'package:gearlease/features/telemetry/domain/entities/predictive_alert.dart';
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
    vibrationG: 0.45,
    status: MachineStatus.warning,
    currentBillingCents: 112000,
    billingType: 'Revenue-Indexed',
    timestamp: DateTime.parse('2026-11-04T10:30:00Z'),
  );

  final testAlert = PredictiveAlert(
    alertId: 'alt-probat-thermal',
    assetId: 'ast_probat12',
    severity: AlertSeverity.CRITICAL,
    title: 'High Thermal Drift Detected',
    description: 'Internal chamber operating at 78.0°C exceeds normal range.',
    suggestedAction: 'Inspect cooling loop and thermal sensor calibration.',
    timestamp: DateTime.parse('2026-11-04T10:30:00Z'),
  );

  setUpAll(() {
    registerFallbackValue(const StartTelemetryStream('ast_probat12'));
    registerFallbackValue(const StopTelemetryStream());
    registerFallbackValue(const TelemetryScheduleServiceRequested(assetId: 'ast_probat12'));
    registerFallbackValue(const AcknowledgeAlert('alt-probat-thermal'));
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

  group('Phase 22 — MachineDiagnosticsScreen Specification Tests', () {
    testWidgets('Requirement 1: renders Top Live Gauges for RPM dial gauge, thermal reading, and vibration metric', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        TelemetryLive(
          testTelemetry,
          const [],
          [testTelemetry],
        ),
      ));
      await tester.pump();

      expect(find.text('IOT MACHINE DIAGNOSTICS'), findsOneWidget);
      expect(find.text('Probat P12 Roaster'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);

      // RPM dial gauge
      expect(find.byKey(const Key('rpm_dial_gauge')), findsOneWidget);
      expect(find.text('1,420'), findsOneWidget);
      expect(find.text('MOTOR RPM'), findsOneWidget);

      // Thermal reading gauge
      expect(find.byKey(const Key('thermal_reading_gauge')), findsOneWidget);
      expect(find.text('78.0°C'), findsOneWidget);
      expect(find.text('OPERATING TEMP'), findsOneWidget);

      // Vibration metric gauge
      expect(find.byKey(const Key('vibration_metric_gauge')), findsOneWidget);
      expect(find.text('0.45 G'), findsOneWidget);
      expect(find.text('VIBRATION METRIC'), findsOneWidget);
    });

    testWidgets('Requirement 2: renders Historical Trend LineChart with threshold guide lines (95°C line)', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        TelemetryLive(
          testTelemetry,
          const [],
          [testTelemetry],
        ),
      ));
      await tester.pump();

      // LineChart widget
      expect(find.byType(LineChart), findsOneWidget);

      // Historical trend title & threshold indicator
      expect(find.text('LIVE TELEMETRY WAVEFORM (60 MIN)'), findsOneWidget);
      expect(find.text('95°C Threshold'), findsOneWidget);
    });

    testWidgets('Requirement 3: renders Active Predictive Alerts Section with severity pill, timestamp, and dismiss CTA', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        TelemetryLive(
          testTelemetry,
          [testAlert],
          [testTelemetry],
        ),
      ));
      await tester.pump();

      expect(find.text('ACTIVE PREDICTIVE ALERTS (1)'), findsOneWidget);
      expect(find.text('High Thermal Drift Detected'), findsOneWidget);
      expect(find.text('CRITICAL'), findsOneWidget);
      expect(find.textContaining('Nov 04'), findsOneWidget);
      expect(find.text('Inspect cooling loop and thermal sensor calibration.'), findsOneWidget);

      // Acknowledge alert CTA button
      expect(find.byKey(const Key('acknowledge_alert_alt-probat-thermal')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('acknowledge_alert_alt-probat-thermal')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acknowledge_alert_alt-probat-thermal')));
      await tester.pump();

      verify(() => mockTelemetryBloc.add(const AcknowledgeAlert('alt-probat-thermal'))).called(1);
    });

    testWidgets('Requirement 4: renders Schedule Preventive Warranty Service button and dispatches service request', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        TelemetryLive(
          testTelemetry,
          [testAlert],
          [testTelemetry],
        ),
      ));
      await tester.pump();

      expect(find.byKey(const Key('schedule_service_button')), findsOneWidget);
      expect(find.textContaining('Schedule Preventive Warranty Service'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('schedule_service_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('schedule_service_button')));
      await tester.pump();

      verify(() => mockTelemetryBloc.add(any(that: isA<TelemetryScheduleServiceRequested>()))).called(1);
    });

    testWidgets('renders CircularProgressIndicator when state is TelemetryConnecting', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(TelemetryConnecting()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders TelemetryOffline view with cache warning banner', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(TelemetryOffline(testTelemetry)));
      await tester.pump();

      expect(find.text('OFFLINE CACHE — DISPLAYING LAST KNOWN TELEMETRY'), findsOneWidget);
      expect(find.text('Probat P12 Roaster'), findsOneWidget);
    });
  });
}
