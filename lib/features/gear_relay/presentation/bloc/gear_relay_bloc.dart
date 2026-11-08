import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/inspection_angle.dart';
import '../../domain/repositories/gear_relay_repository.dart';
import 'gear_relay_event.dart';
import 'gear_relay_state.dart';

class GearRelayBloc extends Bloc<GearRelayEvent, GearRelayState> {
  final GearRelayRepository repository;

  static List<InspectionAngle> get defaultAngles => const [
        InspectionAngle(
          type: InspectionAngleType.frontProfile,
          title: InspectionAngle.angle1Title,
          description: 'Capture entire machine profile from 6-8 feet with clear perimeter clearance.',
        ),
        InspectionAngle(
          type: InspectionAngleType.serialTag,
          title: InspectionAngle.angle2Title,
          description: 'Macro focus on manufacturer metal tag, stamped serial, and electrical specs.',
        ),
        InspectionAngle(
          type: InspectionAngleType.engineHousing,
          title: InspectionAngle.angle3Title,
          description: 'Inspect drive belts, hydraulic connections, and primary motor cooling vents.',
        ),
        InspectionAngle(
          type: InspectionAngleType.controlDisplay,
          title: InspectionAngle.angle4Title,
          description: 'Capture digital screen showing lifetime running hours and active diagnostic codes.',
        ),
      ];

  GearRelayBloc({required this.repository}) : super(GearRelayInitial()) {
    on<GearRelayStarted>(_onStarted);
    on<GearRelayAngleSelected>(_onAngleSelected);
    on<GearRelayPhotoCaptured>(_onPhotoCaptured);
    on<GearRelaySubmitRequested>(_onSubmitRequested);
  }

  void _onStarted(GearRelayStarted event, Emitter<GearRelayState> emit) {
    emit(GearRelayActive(
      assetId: event.assetId,
      angles: defaultAngles,
    ));
  }

  void _onAngleSelected(GearRelayAngleSelected event, Emitter<GearRelayState> emit) {
    if (state is GearRelayActive) {
      final current = state as GearRelayActive;
      if (event.angleIndex >= 0 && event.angleIndex < current.angles.length) {
        emit(current.copyWith(currentAngleIndex: event.angleIndex));
      }
    }
  }

  void _onPhotoCaptured(GearRelayPhotoCaptured event, Emitter<GearRelayState> emit) {
    if (state is GearRelayActive) {
      final current = state as GearRelayActive;
      final updatedAngles = List<InspectionAngle>.from(current.angles);

      updatedAngles[event.angleIndex] = updatedAngles[event.angleIndex].copyWith(
        localFilePath: event.imagePath,
        isCaptured: true,
      );

      // Auto-advance to next uncaptured angle if available
      int nextIndex = current.currentAngleIndex;
      for (int i = 0; i < updatedAngles.length; i++) {
        if (!updatedAngles[i].isCaptured) {
          nextIndex = i;
          break;
        }
      }

      emit(current.copyWith(
        angles: updatedAngles,
        currentAngleIndex: nextIndex,
      ));
    }
  }

  Future<void> _onSubmitRequested(
    GearRelaySubmitRequested event,
    Emitter<GearRelayState> emit,
  ) async {
    if (state is GearRelayActive) {
      final current = state as GearRelayActive;
      emit(current.copyWith(isSubmitting: true));

      try {
        final photoMap = <String, String>{};
        for (final angle in current.angles) {
          if (angle.localFilePath != null) {
            photoMap[angle.title] = angle.localFilePath!;
          }
        }

        final result = await repository.submitInspectionBundle(
          event.assetId,
          photoMap,
        );

        result.when(
          success: (inspection) {
            emit(current.copyWith(
              isSubmitting: false,
              completedValuationId: inspection.inspectionId,
            ));
          },
          failure: (failure) {
            emit(current.copyWith(
              isSubmitting: false,
              errorMessage: failure.message,
            ));
          },
        );
      } catch (e) {
        emit(current.copyWith(
          isSubmitting: false,
          errorMessage: e.toString(),
        ));
      }
    }
  }
}
