import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/error/failures.dart';
import 'package:gearlease/core/utils/result.dart';
import 'package:gearlease/features/gear_relay/domain/entities/inspection_angle.dart';
import 'package:gearlease/features/gear_relay/domain/entities/return_inspection.dart';
import 'package:gearlease/features/gear_relay/domain/repositories/gear_relay_repository.dart';

class FakeGearRelayRepository implements GearRelayRepository {
  ReturnInspection? mockInspection;
  Failure? mockFailure;
  String? capturedLeaseId;
  Map<String, String>? capturedPhotoPaths;

  @override
  Future<Result<ReturnInspection, Failure>> submitInspectionBundle(
    String leaseId,
    Map<String, String> photoPaths,
  ) async {
    capturedLeaseId = leaseId;
    capturedPhotoPaths = photoPaths;
    if (mockFailure != null) {
      return Result.failure(mockFailure!);
    }
    return Result.success(mockInspection ??
        ReturnInspection(
          inspectionId: 'insp_123',
          leaseId: leaseId,
          assetId: 'ast_456',
          inspectionDate: DateTime.now(),
          overallGrade: ReturnInspectionGrade.A_EXCELLENT,
          photoPaths: photoPaths,
        ));
  }
}

void main() {
  group('InspectionAngle Domain Entity Tests', () {
    const angle1 = InspectionAngle(
      type: InspectionAngleType.frontProfile,
      title: 'Angle 1: Front Full Profile',
      description: 'Capture entire machine profile from 6-8 feet.',
    );

    test('supports value equality via Equatable', () {
      const duplicate = InspectionAngle(
        type: InspectionAngleType.frontProfile,
        title: 'Angle 1: Front Full Profile',
        description: 'Capture entire machine profile from 6-8 feet.',
      );

      expect(angle1, equals(duplicate));
    });

    test('copyWith updates localFilePath and isCaptured flag', () {
      final updated = angle1.copyWith(
        localFilePath: '/tmp/front_photo.jpg',
        isCaptured: true,
      );

      expect(updated.isCaptured, isTrue);
      expect(updated.localFilePath, '/tmp/front_photo.jpg');
      expect(updated.type, angle1.type);
    });
  });

  group('Phase 23: 4 Required Inspection Photo Angles Specifications', () {
    test('defines exact 4 required inspection photos in order', () {
      expect(InspectionAngle.requiredPhotoAngles, equals([
        'Angle 1: Front Full Profile',
        'Angle 2: Manufacturer Serial & Barcode Tag',
        'Angle 3: Engine Housing / Motor Bay',
        'Angle 4: Digital Control Display & Hour Meter',
      ]));

      expect(InspectionAngle.angle1Title, equals('Angle 1: Front Full Profile'));
      expect(InspectionAngle.angle2Title, equals('Angle 2: Manufacturer Serial & Barcode Tag'));
      expect(InspectionAngle.angle3Title, equals('Angle 3: Engine Housing / Motor Bay'));
      expect(InspectionAngle.angle4Title, equals('Angle 4: Digital Control Display & Hour Meter'));
    });

    test('InspectionAngleType exposes default titles matching prompt specification', () {
      expect(InspectionAngleType.frontProfile.defaultTitle, equals('Angle 1: Front Full Profile'));
      expect(InspectionAngleType.serialTag.defaultTitle, equals('Angle 2: Manufacturer Serial & Barcode Tag'));
      expect(InspectionAngleType.engineHousing.defaultTitle, equals('Angle 3: Engine Housing / Motor Bay'));
      expect(InspectionAngleType.controlDisplay.defaultTitle, equals('Angle 4: Digital Control Display & Hour Meter'));
    });
  });

  group('Phase 23: ReturnInspection Domain Entity & Grade Specifications', () {
    final now = DateTime.utc(2026, 11, 8, 22, 0, 0);

    test('supports all 4 inspection grades: A_EXCELLENT, B_GOOD, C_FAIR, D_DAMAGED', () {
      expect(ReturnInspectionGrade.A_EXCELLENT.code, equals('A_EXCELLENT'));
      expect(ReturnInspectionGrade.B_GOOD.code, equals('B_GOOD'));
      expect(ReturnInspectionGrade.C_FAIR.code, equals('C_FAIR'));
      expect(ReturnInspectionGrade.D_DAMAGED.code, equals('D_DAMAGED'));

      expect(ReturnInspectionGrade.fromString('A_EXCELLENT'), equals(ReturnInspectionGrade.A_EXCELLENT));
      expect(ReturnInspectionGrade.fromString('b_good'), equals(ReturnInspectionGrade.B_GOOD));
      expect(ReturnInspectionGrade.fromString('C_FAIR'), equals(ReturnInspectionGrade.C_FAIR));
      expect(ReturnInspectionGrade.fromString('D_DAMAGED'), equals(ReturnInspectionGrade.D_DAMAGED));
    });

    test('creates ReturnInspection entity with required fields and supports Equatable', () {
      final inspection1 = ReturnInspection(
        inspectionId: 'insp_001',
        leaseId: 'lease_999',
        assetId: 'ast_456',
        inspectionDate: now,
        overallGrade: ReturnInspectionGrade.A_EXCELLENT,
        photoPaths: const {
          'Angle 1: Front Full Profile': '/photos/angle1.jpg',
          'Angle 2: Manufacturer Serial & Barcode Tag': '/photos/angle2.jpg',
          'Angle 3: Engine Housing / Motor Bay': '/photos/angle3.jpg',
          'Angle 4: Digital Control Display & Hour Meter': '/photos/angle4.jpg',
        },
      );

      final inspection2 = ReturnInspection(
        inspectionId: 'insp_001',
        leaseId: 'lease_999',
        assetId: 'ast_456',
        inspectionDate: now,
        overallGrade: ReturnInspectionGrade.A_EXCELLENT,
        photoPaths: const {
          'Angle 1: Front Full Profile': '/photos/angle1.jpg',
          'Angle 2: Manufacturer Serial & Barcode Tag': '/photos/angle2.jpg',
          'Angle 3: Engine Housing / Motor Bay': '/photos/angle3.jpg',
          'Angle 4: Digital Control Display & Hour Meter': '/photos/angle4.jpg',
        },
      );

      expect(inspection1, equals(inspection2));
      expect(inspection1.inspectionId, equals('insp_001'));
      expect(inspection1.leaseId, equals('lease_999'));
      expect(inspection1.assetId, equals('ast_456'));
      expect(inspection1.inspectionDate, equals(now));
      expect(inspection1.overallGrade, equals(ReturnInspectionGrade.A_EXCELLENT));
      expect(inspection1.photoPaths.length, equals(4));
    });

    test('copyWith properly modifies ReturnInspection fields', () {
      final inspection = ReturnInspection(
        inspectionId: 'insp_001',
        leaseId: 'lease_999',
        assetId: 'ast_456',
        inspectionDate: now,
        overallGrade: ReturnInspectionGrade.B_GOOD,
      );

      final updated = inspection.copyWith(
        overallGrade: ReturnInspectionGrade.D_DAMAGED,
        photoPaths: {'Angle 1: Front Full Profile': '/photos/angle1_updated.jpg'},
      );

      expect(updated.overallGrade, equals(ReturnInspectionGrade.D_DAMAGED));
      expect(updated.photoPaths['Angle 1: Front Full Profile'], equals('/photos/angle1_updated.jpg'));
      expect(updated.inspectionId, equals(inspection.inspectionId));
      expect(updated.leaseId, equals(inspection.leaseId));
    });

    test('toJson and fromJson correctly serialize and deserialize ReturnInspection', () {
      final original = ReturnInspection(
        inspectionId: 'insp_888',
        leaseId: 'lease_777',
        assetId: 'ast_555',
        inspectionDate: now,
        overallGrade: ReturnInspectionGrade.C_FAIR,
        photoPaths: const {
          'Angle 1: Front Full Profile': '/images/a1.png',
        },
      );

      final json = original.toJson();
      expect(json['inspection_id'], equals('insp_888'));
      expect(json['lease_id'], equals('lease_777'));
      expect(json['asset_id'], equals('ast_555'));
      expect(json['inspection_date'], equals(now.toIso8601String()));
      expect(json['overall_grade'], equals('C_FAIR'));
      expect(json['photo_paths'], equals({'Angle 1: Front Full Profile': '/images/a1.png'}));

      final restored = ReturnInspection.fromJson(json);
      expect(restored, equals(original));
    });
  });

  group('Phase 23: GearRelayRepository Contract Specifications', () {
    test('submitInspectionBundle executes and returns Result<ReturnInspection, Failure>', () async {
      final fakeRepo = FakeGearRelayRepository();
      const leaseId = 'lease_test_contract_123';
      const photos = {
        'Angle 1: Front Full Profile': '/var/photos/front.png',
        'Angle 2: Manufacturer Serial & Barcode Tag': '/var/photos/serial.png',
      };

      final result = await fakeRepo.submitInspectionBundle(leaseId, photos);

      expect(result.isSuccess, isTrue);
      expect(fakeRepo.capturedLeaseId, equals(leaseId));
      expect(fakeRepo.capturedPhotoPaths, equals(photos));
      expect(result.dataOrNull?.leaseId, equals(leaseId));
      expect(result.dataOrNull?.overallGrade, equals(ReturnInspectionGrade.A_EXCELLENT));
    });

    test('submitInspectionBundle failure returns Result with Failure object', () async {
      final fakeRepo = FakeGearRelayRepository();
      fakeRepo.mockFailure = const ServerFailure('Camera bundle upload failed');

      final result = await fakeRepo.submitInspectionBundle('lease_fail_123', {});

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ServerFailure>());
      expect(result.failureOrNull?.message, equals('Camera bundle upload failed'));
    });
  });
}
