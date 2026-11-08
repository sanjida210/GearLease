import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/data/datasources/biometric_local_datasource.dart';
import '../../domain/entities/mobile_sign_event.dart';
import '../../domain/repositories/signature_repository.dart';
import 'signature_event.dart';
import 'signature_state.dart';

class SignatureBloc extends Bloc<SignatureEvent, SignatureState> {
  final SignatureRepository signatureRepository;
  final BiometricLocalDataSource biometricDataSource;

  SignatureBloc({
    required this.signatureRepository,
    required this.biometricDataSource,
  }) : super(SignatureInitial()) {
    on<SignatureStrokeAdded>(_onStrokeAdded);
    on<SignatureCleared>(_onCleared);
    on<SignatureSubmitted>(_onSubmitted);
  }

  void _onStrokeAdded(SignatureStrokeAdded event, Emitter<SignatureState> emit) {
    emit(SignatureDrawing(event.strokeCount));
  }

  void _onCleared(SignatureCleared event, Emitter<SignatureState> emit) {
    emit(SignatureInitial());
  }

  Future<void> _onSubmitted(
    SignatureSubmitted event,
    Emitter<SignatureState> emit,
  ) async {
    emit(SignatureSubmitting());

    if (event.requiresBiometricAudit) {
      final authenticated = await biometricDataSource.authenticate(
        reason: 'Authorize digital contract execution',
      );
      if (!authenticated) {
        emit(const SignatureFailureState(
          'Biometric authorization required to execute contract.',
        ));
        return;
      }
    }

    final signEvent = MobileSignEvent(
      id: const Uuid().v4(),
      contractId: event.contractId,
      signerUserId: 'usr-active-signer',
      biometricUsed: event.requiresBiometricAudit ? 'FACE_ID' : null,
      signatureVectorPath: event.signatureSvg,
      signerIp: '127.0.0.1',
      gpsLatitude: 37.7749,
      gpsLongitude: -122.4194,
      signedAt: DateTime.now(),
    );

    final result = await signatureRepository.submitSignature(signEvent);
    result.when(
      success: (data) => emit(SignatureSuccess(data)),
      failure: (failure) => emit(
        SignatureFailureState('${failure.runtimeType}: ${failure.message}'),
      ),
    );
  }
}
