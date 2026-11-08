import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthBiometricLoginRequested>(_onAuthBiometricLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.getActiveSession();
    result.when(
      success: (session) {
        if (session != null) {
          emit(AuthAuthenticated(session));
        } else {
          emit(AuthUnauthenticated());
        }
      },
      failure: (_) => emit(AuthUnauthenticated()),
    );
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.loginWithCredentials(
      event.email,
      event.password,
    );
    result.when(
      success: (session) => emit(AuthAuthenticated(session)),
      failure: (failure) => emit(AuthFailureState(failure.toString())),
    );
  }

  Future<void> _onAuthBiometricLoginRequested(
    AuthBiometricLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.authenticateWithBiometrics();
    result.when(
      success: (session) => emit(AuthAuthenticated(session)),
      failure: (failure) => emit(AuthFailureState(failure.toString())),
    );
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await authRepository.logout();
    emit(AuthUnauthenticated());
  }
}
