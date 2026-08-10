import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

import 'package:google_sign_in/google_sign_in.dart';

enum AuthStatus { checking, loggedOut, loggedIn }

@immutable
class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? error;

  const AuthState({
    required this.status,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? error,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService = AuthService();

  AuthNotifier() : super(const AuthState(status: AuthStatus.checking)) {
    checkAuthState();
  }

  Future<void> _loadRecent() async {
    // Left empty/ignored as it was a copy error in prompt, not needed for AuthNotifier
  }

  Future<void> checkAuthState() async {
    final user = await _authService.fetchCurrentUser();
    state = AuthState(
      status: user != null ? AuthStatus.loggedIn : AuthStatus.loggedOut,
      user: user,
    );
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(clearError: true);
    try {
      final user = await _authService.login(email: email, password: password);
      state = AuthState(status: AuthStatus.loggedIn, user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.loggedOut, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.loggedOut,
        error: 'Failed to connect. Check your internet/firewall.',
      );
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(clearError: true);
    try {
      final user = await _authService.register(
        name: name,
        email: email,
        password: password,
      );
      state = AuthState(status: AuthStatus.loggedIn, user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.loggedOut, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.loggedOut,
        error: 'Failed to connect. Check your internet/firewall.',
      );
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = state.copyWith(clearError: true);
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      final account = await googleSignIn.signIn();
      if (account == null) return false; // user cancelled

      final authKeys = await account.authentication;
      final idToken = authKeys.idToken;
      if (idToken == null) {
        state = state.copyWith(status: AuthStatus.loggedOut, error: 'Failed to retrieve Google ID Token.');
        return false;
      }

      final user = await _authService.loginWithGoogle(idToken);
      state = AuthState(status: AuthStatus.loggedIn, user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.loggedOut, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.loggedOut,
        error: 'Google Sign-In failed: $e',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.loggedOut);
  }
}

/// Global auth provider — available everywhere in the widget tree via ref.watch.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
