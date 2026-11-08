import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/gear_relay/presentation/bloc/gear_relay_bloc.dart';
import 'package:gearlease/features/gear_relay/presentation/bloc/gear_relay_event.dart';
import 'package:gearlease/features/gear_relay/presentation/bloc/gear_relay_state.dart';
import 'package:gearlease/features/gear_relay/presentation/screens/gear_relay_guide_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class MockGearRelayBloc extends Mock implements GearRelayBloc {}
class MockImagePicker extends Mock implements ImagePicker {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGearRelayBloc mockBloc;
  late MockImagePicker mockImagePicker;

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
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget createWidgetUnderTest(GearRelayState state) {
    when(() => mockBloc.state).thenReturn(state);

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: BlocProvider<GearRelayBloc>.value(
        value: mockBloc,
        child: GearRelayGuideScreen(
          assetId: 'ast_probat12',
          imagePicker: mockImagePicker,
        ),
      ),
    );
  }

  group('GearRelayGuideScreen Widget Tests', () {
    testWidgets('renders step tabs, viewfinder overlay, and capture button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(activeState));
      await tester.pump();

      expect(find.text('GEARRELAY RETURN GUIDE'), findsOneWidget);
      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Step 4'), findsOneWidget);
      expect(find.text('FRONT PROFILE SILHOUETTE'), findsOneWidget);
      expect(find.byKey(const Key('capture_angle_button')), findsOneWidget);
    });

    testWidgets('taps capture button and dispatches GearRelayPhotoCaptured', (tester) async {
      when(() => mockImagePicker.pickImage(source: ImageSource.camera)).thenAnswer(
        (_) async => XFile('/mock/captured_photo.jpg'),
      );

      await tester.pumpWidget(createWidgetUnderTest(activeState));
      await tester.pump();

      await tester.tap(find.byKey(const Key('capture_angle_button')));
      await tester.pump();

      verify(() => mockBloc.add(any(that: isA<GearRelayPhotoCaptured>()))).called(1);
    });

    testWidgets('renders submit bundle button when all angles captured', (tester) async {
      final allCaptured = GearRelayActive(
        assetId: 'ast_probat12',
        angles: GearRelayBloc.defaultAngles.map((a) => a.copyWith(isCaptured: true)).toList(),
      );

      await tester.pumpWidget(createWidgetUnderTest(allCaptured));
      await tester.pump();

      expect(find.byKey(const Key('submit_bundle_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('submit_bundle_button')));
      await tester.pump();

      verify(() => mockBloc.add(any(that: isA<GearRelaySubmitRequested>()))).called(1);
    });

    testWidgets('renders success valuation ticket card upon submission complete', (tester) async {
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
