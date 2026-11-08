import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/features/gear_relay/domain/repositories/gear_relay_repository.dart';
import 'package:gearlease/features/gear_relay/presentation/bloc/gear_relay_bloc.dart';
import 'package:gearlease/features/gear_relay/presentation/bloc/gear_relay_event.dart';
import 'package:gearlease/features/gear_relay/presentation/bloc/gear_relay_state.dart';
import 'package:mocktail/mocktail.dart';

class MockGearRelayRepository extends Mock implements GearRelayRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGearRelayRepository mockRepository;
  late GearRelayBloc gearRelayBloc;

  setUp(() {
    mockRepository = MockGearRelayRepository();
    gearRelayBloc = GearRelayBloc(repository: mockRepository);
  });

  tearDown(() {
    gearRelayBloc.close();
  });

  group('GearRelayBloc Tests', () {
    test('initial state is GearRelayInitial', () {
      expect(gearRelayBloc.state, equals(GearRelayInitial()));
    });

    blocTest<GearRelayBloc, GearRelayState>(
      'emits GearRelayActive with 4 default angles on GearRelayStarted',
      build: () => gearRelayBloc,
      act: (bloc) => bloc.add(const GearRelayStarted('ast_probat12')),
      expect: () => [
        isA<GearRelayActive>()
            .having((s) => s.assetId, 'assetId', 'ast_probat12')
            .having((s) => s.angles.length, 'angles.length', 4)
            .having((s) => s.currentAngleIndex, 'currentAngleIndex', 0),
      ],
    );

    blocTest<GearRelayBloc, GearRelayState>(
      'changes currentAngleIndex on GearRelayAngleSelected',
      build: () => gearRelayBloc,
      seed: () => GearRelayActive(
        assetId: 'ast_probat12',
        angles: GearRelayBloc.defaultAngles,
      ),
      act: (bloc) => bloc.add(const GearRelayAngleSelected(2)),
      expect: () => [
        isA<GearRelayActive>().having((s) => s.currentAngleIndex, 'currentAngleIndex', 2),
      ],
    );

    blocTest<GearRelayBloc, GearRelayState>(
      'updates captured photo on GearRelayPhotoCaptured and advances step',
      build: () => gearRelayBloc,
      seed: () => GearRelayActive(
        assetId: 'ast_probat12',
        angles: GearRelayBloc.defaultAngles,
      ),
      act: (bloc) => bloc.add(const GearRelayPhotoCaptured(
        angleIndex: 0,
        imagePath: '/tmp/angle_0.jpg',
      )),
      expect: () => [
        isA<GearRelayActive>()
            .having((s) => s.angles[0].isCaptured, 'angle[0].isCaptured', isTrue)
            .having((s) => s.angles[0].localFilePath, 'angle[0].localFilePath', '/tmp/angle_0.jpg')
            .having((s) => s.currentAngleIndex, 'currentAngleIndex', 1),
      ],
    );

    blocTest<GearRelayBloc, GearRelayState>(
      'submits inspection bundle and emits completedValuationId on GearRelaySubmitRequested',
      build: () {
        when(() => mockRepository.submitInspectionBundle(
              assetId: any(named: 'assetId'),
              angles: any(named: 'angles'),
            )).thenAnswer((_) async => 'cpo_val_883311');
        return gearRelayBloc;
      },
      seed: () => GearRelayActive(
        assetId: 'ast_probat12',
        angles: GearRelayBloc.defaultAngles.map((a) => a.copyWith(isCaptured: true)).toList(),
      ),
      act: (bloc) => bloc.add(const GearRelaySubmitRequested('ast_probat12')),
      expect: () => [
        isA<GearRelayActive>().having((s) => s.isSubmitting, 'isSubmitting', isTrue),
        isA<GearRelayActive>()
            .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
            .having((s) => s.completedValuationId, 'completedValuationId', 'cpo_val_883311'),
      ],
    );
  });
}
