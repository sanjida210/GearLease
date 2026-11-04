import 'package:equatable/equatable.dart';

enum InspectionAngleType {
  frontProfile,
  serialTag,
  engineHousing,
  controlDisplay,
}

class InspectionAngle extends Equatable {
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
