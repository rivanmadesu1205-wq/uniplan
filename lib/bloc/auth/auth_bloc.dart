import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../services/auth_service.dart';

sealed class AuthEvent {
  const AuthEvent();
}

final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});
}

final class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String nama;
  final String nim;
  final String prodi;

  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.nama,
    required this.nim,
    required this.prodi,
  });
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

sealed class AuthState {
  const AuthState();
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthUnauthenticated extends AuthState {
  final String? message;

  const AuthUnauthenticated({this.message});
}

final class AuthAuthenticated extends AuthState {
  final supabase.User? user;

  const AuthAuthenticated(this.user);
}

final class AuthRegistrationSuccess extends AuthState {
  final bool isAuthenticated;
  final String message;

  const AuthRegistrationSuccess({
    required this.isAuthenticated,
    required this.message,
  });
}

final class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthBloc({AuthService? authService})
    : _authService = authService ?? AuthService(),
      super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }

      // Subscribe only once. Re-subscribing here causes Supabase to emit the
      // current session again, which can restart AuthStarted indefinitely.
      if (_authSubscription != null) return;

      _authSubscription = _authService.authStateChanges.listen((data) {
        if (data.event == supabase.AuthChangeEvent.signedOut ||
            data.session?.user != null) {
          add(const AuthStarted());
        }
      });
    } on StateError {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authService.login(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(user));
    } catch (error) {
      emit(AuthFailure(error.toString()));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authService.register(
        email: event.email,
        password: event.password,
        nama: event.nama,
        nim: event.nim,
        prodi: event.prodi,
      );
      final isAuthenticated = _authService.currentUser != null;
      emit(
        AuthRegistrationSuccess(
          isAuthenticated: isAuthenticated,
          message: isAuthenticated
              ? 'Registrasi berhasil! Akun Anda telah dibuat.'
              : 'Registrasi berhasil. Periksa email Anda untuk konfirmasi.',
        ),
      );
      if (isAuthenticated && user != null) {
        emit(AuthAuthenticated(user));
      }
    } catch (error) {
      emit(AuthFailure(error.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.logout();
      emit(const AuthUnauthenticated());
    } catch (error) {
      emit(AuthFailure(error.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    return super.close();
  }
}
