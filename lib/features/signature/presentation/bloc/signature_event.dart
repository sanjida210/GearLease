import 'package:equatable/equatable.dart';
import '../../domain/entities/signature_payload_bundle.dart';

abstract class SignatureEvent extends Equatable {
  const SignatureEvent();

  @override
  List<Object?> get props => [];
}

class SignatureStrokeAdded extends SignatureEvent {
  final int strokeCount;

  const SignatureStrokeAdded(this.strokeCount);

  @override
  List<Object?> get props => [strokeCount];
}

class SignatureCleared extends SignatureEvent {}

class SignatureSubmitted extends SignatureEvent {
  final String contractId;
  final String signatureSvg;
  final bool requiresBiometricAudit;
  final SignaturePayloadBundle? payloadBundle;

  const SignatureSubmitted({
    required this.contractId,
    required this.signatureSvg,
    this.requiresBiometricAudit = false,
    this.payloadBundle,
  });

  @override
  List<Object?> get props => [
        contractId,
        signatureSvg,
        requiresBiometricAudit,
        payloadBundle,
      ];
}
