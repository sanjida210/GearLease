import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/gear_relay/data/services/image_compression_service.dart';
import 'package:gearlease/features/gear_relay/presentation/bloc/gear_relay_bloc.dart';
import 'package:gearlease/features/gear_relay/presentation/bloc/gear_relay_event.dart';
import 'package:gearlease/features/gear_relay/presentation/bloc/gear_relay_state.dart';
import 'package:gearlease/features/gear_relay/presentation/screens/gear_relay_guide_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class MockGearRelayBloc extends Mock implements GearRelayBloc {}
class MockImagePicker extends Mock implements ImagePicker {}
class MockImageCompressionService extends Mock implements ImageCompressionService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGearRelayBloc mockBloc;
  late MockImagePicker mockImagePicker;
  late MockImageCompressionService mockCompressionService;
  late StreamController<GearRelayState> stateController;

  final activeState = GearRelayActive(
    assetId: 'ast_probat12',
    angles: GearRelayBloc.defaultAngles,
  );

  setUpAll(() {
    registerFallbackValue(const GearRelayStarted('ast_probat12'));
    registerFallbackValue(const GearRelayPhotoCaptured(angleIndex: 0, imagePath: ''));
    registerFallbackValue(const GearRelaySubmitRequested('ast_probat12'));
  });

  setUp(() {
    mockBloc = MockGearRelayBloc();
    mockImagePicker = MockImagePicker();
    mockCompressionService = MockImageCompressionService();
    stateController = StreamController<GearRelayState>.broadcast();

    when(() => mockBloc.stream).thenAnswer((_) => stateController.stream);
    when(() => mockCompressionService.compressImage(any())).thenAnswer(
      (inv) async => '${inv.positionalArguments[0]}_compressed.jpg',
    );
  });

  tearDown(() {
    stateController.close();
  });

  Widget createWidgetUnderTest(
    GearRelayState state, {
    Key? key,
    ImageCompressionService? compressionService,
  }) {
    when(() => mockBloc.state).thenReturn(state);

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: BlocProvider<GearRelayBloc>.value(
        value: mockBloc,
        child: GearRelayGuideScreen(
          key: key,
          assetId: 'ast_probat12',
          imagePicker: mockImagePicker,
          compressionService: compressionService ?? mockCompressionService,
        ),
      ),
    );
  }

  group('Phase 24: GearRelayGuideScreen Specification Tests', () {
    testWidgets('Requirement 1: renders step-by-step progress indicator (Angle 1 of 4)', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(activeState));
      await tester.pump();

      expect(find.text('GEARRELAY RETURN GUIDE'), findsOneWidget);
      expect(find.byKey(const Key('angle_progress_indicator')), findsOneWidget);
      expect(find.text('Angle 1 of 4'), findsOneWidget);
      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Step 4'), findsOneWidget);
    });

    testWidgets('Requirement 2: renders AR silhouette overlays for each angle type', (tester) async {
      // Angle 1: Front Profile
      await tester.pumpWidget(createWidgetUnderTest(activeState, key: const Key('screen_angle_0')));
      await tester.pump();
      expect(find.text('FRONT PROFILE SILHOUETTE'), findsOneWidget);
      expect(find.byKey(const Key('silhouette_front_profile')), findsOneWidget);

      // Angle 2: Serial Tag Box
      final angle2State = activeState.copyWith(currentAngleIndex: 1);
      await tester.pumpWidget(createWidgetUnderTest(angle2State, key: const Key('screen_angle_1')));
      await tester.pump();
      expect(find.text('SERIAL TAG & BARCODE OVERLAY'), findsOneWidget);
      expect(find.byKey(const Key('silhouette_serial_tag')), findsOneWidget);

      // Angle 3: Engine Housing / Motor Bay
      final angle3State = activeState.copyWith(currentAngleIndex: 2);
      await tester.pumpWidget(createWidgetUnderTest(angle3State, key: const Key('screen_angle_2')));
      await tester.pump();
      expect(find.text('MOTOR & ENGINE HOUSING OVERLAY'), findsOneWidget);
      expect(find.byKey(const Key('silhouette_engine_housing')), findsOneWidget);

      // Angle 4: Hour Meter Circle
      final angle4State = activeState.copyWith(currentAngleIndex: 3);
      await tester.pumpWidget(createWidgetUnderTest(angle4State, key: const Key('screen_angle_3')));
      await tester.pump();
      expect(find.text('DIGITAL HOUR METER OVERLAY'), findsOneWidget);
      expect(find.byKey(const Key('silhouette_hour_meter')), findsOneWidget);
    });

    testWidgets('Requirement 3: Capture flow opens review with Retake & Accept and compresses <500KB', (tester) async {
      when(() => mockImagePicker.pickImage(source: ImageSource.camera)).thenAnswer(
        (_) async => XFile('/raw/camera_photo.jpg'),
      );

      await tester.pumpWidget(createWidgetUnderTest(activeState));
      await tester.pump();

      // Ensure button is visible before tapping
      final captureBtn = find.byKey(const Key('capture_angle_button'));
      await tester.ensureVisible(captureBtn);
      await tester.tap(captureBtn);
      await tester.pumpAndSettle();

      // Verify compression service was called with raw capture path
      verify(() => mockCompressionService.compressImage('/raw/camera_photo.jpg')).called(1);

      // Verify Review Mode is displayed
      expect(find.byKey(const Key('review_preview_card')), findsOneWidget);
      expect(find.byKey(const Key('retake_button')), findsOneWidget);
      expect(find.byKey(const Key('accept_button')), findsOneWidget);
      expect(find.text('JPEG <500KB (Readability Verified)'), findsOneWidget);

      // Tap Retake -> should cancel review and return to capture viewfinder
      final retakeBtn = find.byKey(const Key('retake_button'));
      await tester.ensureVisible(retakeBtn);
      await tester.tap(retakeBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_preview_card')), findsNothing);
      expect(find.byKey(const Key('capture_angle_button')), findsOneWidget);
    });

    testWidgets('Requirement 3 & 4: Accepting captured photo dispatches GearRelayPhotoCaptured', (tester) async {
      when(() => mockImagePicker.pickImage(source: ImageSource.camera)).thenAnswer(
        (_) async => XFile('/raw/valid_angle1.jpg'),
      );

      await tester.pumpWidget(createWidgetUnderTest(activeState));
      await tester.pump();

      // Capture photo
      final captureBtn = find.byKey(const Key('capture_angle_button'));
      await tester.ensureVisible(captureBtn);
      await tester.tap(captureBtn);
      await tester.pumpAndSettle();

      // Accept photo in review mode
      final acceptBtn = find.byKey(const Key('accept_button'));
      await tester.ensureVisible(acceptBtn);
      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();

      // Dispatches GearRelayPhotoCaptured with compressed path
      verify(() => mockBloc.add(const GearRelayPhotoCaptured(
            angleIndex: 0,
            imagePath: '/raw/valid_angle1.jpg_compressed.jpg',
          ))).called(1);
    });

    testWidgets('Requirement 5: Packages image paths and submits CPO bundle when all 4 shots confirmed', (tester) async {
      final allCaptured = GearRelayActive(
        assetId: 'ast_probat12',
        angles: GearRelayBloc.defaultAngles.map((a) => a.copyWith(
          isCaptured: true,
          localFilePath: '/compressed/${a.type.name}.jpg',
        )).toList(),
      );

      await tester.pumpWidget(createWidgetUnderTest(allCaptured));
      await tester.pump();

      final submitBtn = find.byKey(const Key('submit_bundle_button'));
      expect(submitBtn, findsOneWidget);
      expect(find.text('SUBMIT CPO INSPECTION BUNDLE'), findsOneWidget);

      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();

      verify(() => mockBloc.add(const GearRelaySubmitRequested('ast_probat12'))).called(1);
    });

    testWidgets('Renders success screen with valuation ticket when bundle submitted', (tester) async {
      final completed = GearRelayActive(
        assetId: 'ast_probat12',
        angles: GearRelayBloc.defaultAngles,
        completedValuationId: 'cpo_val_998811',
      );

      await tester.pumpWidget(createWidgetUnderTest(completed));
      await tester.pump();

      expect(find.text('INSPECTION BUNDLE SUBMITTED'), findsOneWidget);
      expect(find.text('Valuation Ticket: cpo_val_998811'), findsOneWidget);
      expect(find.text('RETURN TO FLEET'), findsOneWidget);
    });
  });
}
