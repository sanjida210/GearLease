import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<BiometricAuthRequested>(_onBiometricAuthRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAppStarted(
    AppStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.getActiveSession();
    result.when(
      success: (session) {
        if (session != null) {
          emit(Authenticated(session));
        } else {
          emit(Unauthenticated());
        }
      },
      failure: (_) => emit(Unauthenticated()),
    );
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.loginWithCredentials(
      event.email,
      event.password,
    );
    result.when(
      success: (session) => emit(Authenticated(session)),
      failure: (failure) => emit(AuthFailure(failure.toString())),
    );
  }

  Future<void> _onBiometricAuthRequested(
    BiometricAuthRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.authenticateWithBiometrics();
    result.when(
      success: (session) => emit(Authenticated(session)),
      failure: (failure) => emit(AuthFailure(failure.toString())),
    );
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await authRepository.logout();
    emit(Unauthenticated());
  }
}
