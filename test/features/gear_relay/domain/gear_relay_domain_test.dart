import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/features/gear_relay/domain/entities/inspection_angle.dart';

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
}
