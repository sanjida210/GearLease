import 'package:equatable/equatable.dart';
import '../../domain/entities/user_session.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final UserSession session;

  const Authenticated(this.session);

  @override
  List<Object?> get props => [session];
}

class Unauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}

// Backwards-compatible aliases
typedef AuthAuthenticated = Authenticated;
typedef AuthUnauthenticated = Unauthenticated;
typedef AuthFailureState = AuthFailure;
