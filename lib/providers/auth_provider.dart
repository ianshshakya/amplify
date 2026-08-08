import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

enum AuthStatus { checking, loggedOut, loggedIn }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.checking;
  AppUser? _user;
  String? _error;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get error => _error;

  /// Call once at app startup — checks if a saved token is still valid.
  Future<void> checkAuthState() async {
    final user = await _authService.fetchCurrentUser();
    _user = user;
    _status = user != null ? AuthStatus.loggedIn : AuthStatus.loggedOut;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    try {
      _user = await _authService.login(email: email, password: password);
      _status = AuthStatus.loggedIn;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to connect. Check your internet/firewall.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _error = null;
    try {
      _user = await _authService.register(name: name, email: email, password: password);
      _status = AuthStatus.loggedIn;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to connect. Check your internet/firewall.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _status = AuthStatus.loggedOut;
    notifyListeners();
  }
}
