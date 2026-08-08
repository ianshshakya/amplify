import 'api_client.dart';
import 'token_storage.dart';
import '../models/app_user.dart';

class AuthService {
  final ApiClient _api = ApiClient();
  final TokenStorage _tokenStorage = TokenStorage();

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _api.post(
      '/auth/register',
      auth: false,
      body: {'name': name, 'email': email, 'password': password},
    );
    await _tokenStorage.saveToken(res['token'] as String);
    return AppUser.fromJson(res['user'] as Map<String, dynamic>);
  }

  Future<AppUser> login({required String email, required String password}) async {
    final res = await _api.post(
      '/auth/login',
      auth: false,
      body: {'email': email, 'password': password},
    );
    await _tokenStorage.saveToken(res['token'] as String);
    return AppUser.fromJson(res['user'] as Map<String, dynamic>);
  }

  Future<AppUser?> fetchCurrentUser() async {
    final token = await _tokenStorage.getToken();
    if (token == null) return null;

    try {
      final res = await _api.get('/users/me');
      return AppUser.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      // Token is invalid/expired, OR the backend is unreachable (SocketException).
      // Treat as logged out so the app doesn't freeze on the loading screen.
      await _tokenStorage.clearToken();
      return null;
    }
  }

  Future<void> logout() => _tokenStorage.clearToken();
}
