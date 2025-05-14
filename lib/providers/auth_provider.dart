import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;
  final User? user;

  AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
    User? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient _supabase;

  AuthNotifier(this._supabase) : super(AuthState());

  Future<void> register(
    String name,
    String lastName,
    String email,
    String password,
  ) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'last_name': lastName},
      );
      final Session? session = response.session;
      final User? user = response.user;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error en la autenticación: ${e.message}',
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: response.user,
      );

      // if (email == 'user@example.com' && password == 'password') {
      //   state = state.copyWith(isLoading: false, isAuthenticated: true);
      // } else {
      //   state = state.copyWith(
      //     isLoading: false,
      //     errorMessage: 'Credenciales inválidas',
      //   );
      // }
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error en la autenticación: ${e.message}',
      );
    }
  }

  void resetError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    state = state.copyWith(
      isAuthenticated: false,
      user: null,
      errorMessage: null,
      isLoading: false,
    );
  }

  Future<bool> resetPassword(String email) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      await _supabase.auth.resetPasswordForEmail(email);
      state = state.copyWith(isLoading: false, errorMessage: null);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: true, errorMessage: e.toString());
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final supabaseClient = Supabase.instance.client;
  return AuthNotifier(supabaseClient);
});
