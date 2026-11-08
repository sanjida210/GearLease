import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/utils/result.dart';
import 'package:gearlease/features/signature/domain/entities/mobile_sign_event.dart';
import 'package:gearlease/features/signature/domain/repositories/signature_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockSignatureRepository extends Mock implements SignatureRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSignatureRepository mockRepository;

  final testSignEvent = MobileSignEvent(
    id: 'sgn-001',
    contractId: 'ctr-882201',
    signerUserId: 'usr-101',
    biometricUsed: 'FACE_ID',
    signatureVectorPath: 'M10 20 L30 40 L50 60',
    signerIp: '192.168.1.100',
    gpsLatitude: 37.7749,
    gpsLongitude: -122.4194,
    signedAt: DateTime.parse('2026-11-04T10:30:00Z'),
  );

  setUp(() {
    mockRepository = MockSignatureRepository();
  });

  group('MobileSignEvent Entity Tests', () {
    test('supports value equality', () {
      final eventB = MobileSignEvent(
        id: 'sgn-001',
        contractId: 'ctr-882201',
        signerUserId: 'usr-101',
        biometricUsed: 'FACE_ID',
        signatureVectorPath: 'M10 20 L30 40 L50 60',
        signerIp: '192.168.1.100',
        gpsLatitude: 37.7749,
        gpsLongitude: -122.4194,
        signedAt: DateTime.parse('2026-11-04T10:30:00Z'),
      );

      expect(testSignEvent, equals(eventB));
    });

    test('repository submits signature successfully', () async {
      when(() => mockRepository.submitSignature(testSignEvent))
          .thenAnswer((_) async => Result.success(testSignEvent));

      final result = await mockRepository.submitSignature(testSignEvent);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.contractId, 'ctr-882201');
      verify(() => mockRepository.submitSignature(testSignEvent)).called(1);
    });
  });
}
