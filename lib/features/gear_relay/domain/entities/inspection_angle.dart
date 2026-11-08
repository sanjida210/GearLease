import 'package:equatable/equatable.dart';

enum InspectionAngleType {
  frontProfile(
    'Angle 1: Front Full Profile',
    'Capture entire machine profile from 6-8 feet with clear perimeter clearance.',
  ),
  serialTag(
    'Angle 2: Manufacturer Serial & Barcode Tag',
    'Macro focus on manufacturer metal tag, stamped serial, and electrical specs.',
  ),
  engineHousing(
    'Angle 3: Engine Housing / Motor Bay',
    'Inspect drive belts, hydraulic connections, and primary motor cooling vents.',
  ),
  controlDisplay(
    'Angle 4: Digital Control Display & Hour Meter',
    'Capture digital screen showing lifetime running hours and active diagnostic codes.',
  );

  final String defaultTitle;
  final String defaultDescription;

  const InspectionAngleType(this.defaultTitle, this.defaultDescription);
}

class InspectionAngle extends Equatable {
  static const String angle1Title = 'Angle 1: Front Full Profile';
  static const String angle2Title = 'Angle 2: Manufacturer Serial & Barcode Tag';
  static const String angle3Title = 'Angle 3: Engine Housing / Motor Bay';
  static const String angle4Title = 'Angle 4: Digital Control Display & Hour Meter';

  static const List<String> requiredPhotoAngles = [
    angle1Title,
    angle2Title,
    angle3Title,
    angle4Title,
  ];

  final InspectionAngleType type;
  final String title;
  final String description;
  final String? localFilePath;
  final bool isCaptured;

  const InspectionAngle({
    required this.type,
    required this.title,
    required this.description,
    this.localFilePath,
    this.isCaptured = false,
  });

  InspectionAngle copyWith({
    String? localFilePath,
    bool? isCaptured,
  }) {
    return InspectionAngle(
      type: type,
      title: title,
      description: description,
      localFilePath: localFilePath ?? this.localFilePath,
      isCaptured: isCaptured ?? this.isCaptured,
    );
  }

  @override
  List<Object?> get props => [type, title, description, localFilePath, isCaptured];
}
