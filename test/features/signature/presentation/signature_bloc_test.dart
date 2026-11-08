import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/error/failures.dart';
import 'package:gearlease/core/utils/result.dart';
import 'package:gearlease/features/auth/data/datasources/biometric_local_datasource.dart';
import 'package:gearlease/features/signature/domain/entities/mobile_sign_event.dart';
import 'package:gearlease/features/signature/domain/repositories/signature_repository.dart';
import 'package:gearlease/features/signature/presentation/bloc/signature_bloc.dart';
import 'package:gearlease/features/signature/presentation/bloc/signature_event.dart';
import 'package:gearlease/features/signature/presentation/bloc/signature_state.dart';
import 'package:mocktail/mocktail.dart';

class MockSignatureRepository extends Mock implements SignatureRepository {}

class MockBiometricLocalDataSource extends Mock implements BiometricLocalDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSignatureRepository mockRepository;
  late MockBiometricLocalDataSource mockBiometricDataSource;
  late SignatureBloc signatureBloc;

  final testSignEvent = MobileSignEvent(
    id: 'sgn-001',
    contractId: 'ctr-882201',
    signerUserId: 'usr-101',
    biometricUsed: 'FACE_ID',
    signatureVectorPath: 'M10 20 L30 40',
    signerIp: '127.0.0.1',
    gpsLatitude: 37.77,
    gpsLongitude: -122.41,
    signedAt: DateTime.parse('2026-11-04T10:30:00Z'),
  );

  setUpAll(() {
    registerFallbackValue(testSignEvent);
  });

  setUp(() {
    mockRepository = MockSignatureRepository();
    mockBiometricDataSource = MockBiometricLocalDataSource();

    signatureBloc = SignatureBloc(
      signatureRepository: mockRepository,
      biometricDataSource: mockBiometricDataSource,
    );
  });

  tearDown(() {
    signatureBloc.close();
  });

  group('SignatureBloc Tests', () {
    test('initial state is SignatureInitial', () {
      expect(signatureBloc.state, equals(SignatureInitial()));
    });

    blocTest<SignatureBloc, SignatureState>(
      'emits SignatureDrawing on SignatureStrokeAdded',
      build: () => signatureBloc,
      act: (bloc) => bloc.add(const SignatureStrokeAdded(5)),
      expect: () => [
        const SignatureDrawing(5),
      ],
    );

    blocTest<SignatureBloc, SignatureState>(
      'emits SignatureInitial on SignatureCleared',
      build: () => signatureBloc,
      seed: () => const SignatureDrawing(5),
      act: (bloc) => bloc.add(SignatureCleared()),
      expect: () => [
        SignatureInitial(),
      ],
    );

    blocTest<SignatureBloc, SignatureState>(
      'emits [SignatureSubmitting, SignatureSuccess] on successful submit with biometric audit',
      build: () {
        when(() => mockBiometricDataSource.authenticate(reason: any(named: 'reason')))
            .thenAnswer((_) async => true);
        when(() => mockRepository.submitSignature(any()))
            .thenAnswer((_) async => Result.success(testSignEvent));
        return signatureBloc;
      },
      act: (bloc) => bloc.add(const SignatureSubmitted(
        contractId: 'ctr-882201',
        signatureSvg: 'M10 20 L30 40',
        requiresBiometricAudit: true,
      )),
      expect: () => [
        SignatureSubmitting(),
        SignatureSuccess(testSignEvent),
      ],
    );

    blocTest<SignatureBloc, SignatureState>(
      'emits [SignatureSubmitting, SignatureFailureState] when biometric audit cancelled',
      build: () {
        when(() => mockBiometricDataSource.authenticate(reason: any(named: 'reason')))
            .thenAnswer((_) async => false);
        return signatureBloc;
      },
      act: (bloc) => bloc.add(const SignatureSubmitted(
        contractId: 'ctr-882201',
        signatureSvg: 'M10 20 L30 40',
        requiresBiometricAudit: true,
      )),
      expect: () => [
        SignatureSubmitting(),
        const SignatureFailureState('Biometric authorization required to execute contract.'),
      ],
    );

    blocTest<SignatureBloc, SignatureState>(
      'emits [SignatureSubmitting, SignatureFailureState] when repository submission fails',
      build: () {
        when(() => mockRepository.submitSignature(any()))
            .thenAnswer((_) async => Result.failure(const ServerFailure('Contract expired')));
        return signatureBloc;
      },
      act: (bloc) => bloc.add(const SignatureSubmitted(
        contractId: 'ctr-882201',
        signatureSvg: 'M10 20 L30 40',
        requiresBiometricAudit: false,
      )),
      expect: () => [
        SignatureSubmitting(),
        const SignatureFailureState('ServerFailure: Contract expired'),
      ],
    );
  });
}
