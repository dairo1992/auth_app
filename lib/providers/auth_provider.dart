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
    state = state.copyWith(isLoading: true, errorMessage: null, isAuthenticated: false);
    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'last_name': lastName},
      );
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
        isAuthenticated: false
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isAuthenticated: false);

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
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error en la autenticación: ${e.message}',
        isAuthenticated: false
      );
    }
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
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final supabaseClient = Supabase.instance.client;
  return AuthNotifier(supabaseClient);
});
