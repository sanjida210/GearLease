import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure(this.message, {this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];

  @override
  String toString() => '$runtimeType: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.statusCode});
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No network connectivity available.']);
}

class BiometricFailure extends Failure {
  const BiometricFailure(super.message);
}

class HardwareFailure extends Failure {
  const HardwareFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}
