import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered on app launch to inspect secure storage for active sessions.
class AppStarted extends AuthEvent {}

/// Subclass for backwards compatibility.
class AuthCheckRequested extends AppStarted {}

/// Triggered when submitting login credentials.
class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested(this.email, this.password);

  const LoginRequested.named({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// Subclass for backwards compatibility.
class AuthLoginRequested extends LoginRequested {
  const AuthLoginRequested({
    required super.email,
    required super.password,
  }) : super.named();
}

/// Triggered when requesting FaceID / TouchID biometric auth.
class BiometricAuthRequested extends AuthEvent {}

/// Subclass for backwards compatibility.
class AuthBiometricLoginRequested extends BiometricAuthRequested {}

/// Triggered when the user logs out.
class LogoutRequested extends AuthEvent {}

/// Subclass for backwards compatibility.
class AuthLogoutRequested extends LogoutRequested {}
