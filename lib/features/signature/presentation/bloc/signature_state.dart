import 'package:equatable/equatable.dart';
import '../../domain/entities/mobile_sign_event.dart';
import '../../domain/entities/signature_payload_bundle.dart';

abstract class SignatureState extends Equatable {
  const SignatureState();

  @override
  List<Object?> get props => [];
}

class SignatureInitial extends SignatureState {}

class SignatureDrawing extends SignatureState {
  final int strokeCount;

  const SignatureDrawing(this.strokeCount);

  @override
  List<Object?> get props => [strokeCount];
}

class SignatureSubmitting extends SignatureState {}

class SignatureSuccess extends SignatureState {
  final MobileSignEvent signEvent;
  final SignaturePayloadBundle? payloadBundle;

  const SignatureSuccess(this.signEvent, {this.payloadBundle});

  @override
  List<Object?> get props => [signEvent, payloadBundle];
}

class SignatureFailureState extends SignatureState {
  final String message;

  const SignatureFailureState(this.message);

  @override
  List<Object?> get props => [message];
}
