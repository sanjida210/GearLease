import 'package:equatable/equatable.dart';

abstract class GearRelayEvent extends Equatable {
  const GearRelayEvent();

  @override
  List<Object?> get props => [];
}

class GearRelayStarted extends GearRelayEvent {
  final String assetId;

  const GearRelayStarted(this.assetId);

  @override
  List<Object?> get props => [assetId];
}

class GearRelayAngleSelected extends GearRelayEvent {
  final int angleIndex;

  const GearRelayAngleSelected(this.angleIndex);

  @override
  List<Object?> get props => [angleIndex];
}

class GearRelayPhotoCaptured extends GearRelayEvent {
  final int angleIndex;
  final String imagePath;

  const GearRelayPhotoCaptured({
    required this.angleIndex,
    required this.imagePath,
  });

  @override
  List<Object?> get props => [angleIndex, imagePath];
}

class GearRelaySubmitRequested extends GearRelayEvent {
  final String assetId;

  const GearRelaySubmitRequested(this.assetId);

  @override
  List<Object?> get props => [assetId];
}
