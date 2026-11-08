import 'package:equatable/equatable.dart';
import '../../domain/entities/inspection_angle.dart';

abstract class GearRelayState extends Equatable {
  const GearRelayState();

  @override
  List<Object?> get props => [];
}

class GearRelayInitial extends GearRelayState {}

class GearRelayActive extends GearRelayState {
  final String assetId;
  final List<InspectionAngle> angles;
  final int currentAngleIndex;
  final bool isSubmitting;
  final String? completedValuationId;
  final String? errorMessage;

  const GearRelayActive({
    required this.assetId,
    required this.angles,
    this.currentAngleIndex = 0,
    this.isSubmitting = false,
    this.completedValuationId,
    this.errorMessage,
  });

  bool get allAnglesCaptured => angles.isNotEmpty && angles.every((a) => a.isCaptured);

  InspectionAngle get currentAngle => angles[currentAngleIndex];

  GearRelayActive copyWith({
    String? assetId,
    List<InspectionAngle>? angles,
    int? currentAngleIndex,
    bool? isSubmitting,
    String? completedValuationId,
    String? errorMessage,
  }) {
    return GearRelayActive(
      assetId: assetId ?? this.assetId,
      angles: angles ?? this.angles,
      currentAngleIndex: currentAngleIndex ?? this.currentAngleIndex,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      completedValuationId: completedValuationId ?? this.completedValuationId,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        assetId,
        angles,
        currentAngleIndex,
        isSubmitting,
        completedValuationId,
        errorMessage,
      ];
}
