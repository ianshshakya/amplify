import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

/// Thrown when the backend returns a non-2xx response, carrying the
/// server's message so the UI can show something useful instead of a
/// raw stack trace.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Thin wrapper around http that adds the base URL, JSON encoding, and
/// the Authorization header automatically when a token is stored.
///
class ApiClient {
  // If you are using the Android Emulator, you MUST change this back to 'http://10.0.2.2:5000/api'
  // If you are using a real phone, change this to your PC's WiFi IP address (e.g. 192.168.1.X)
  static const String baseUrl = 'http://10.77.236.84:5000/api';

  final TokenStorage _tokenStorage = TokenStorage();

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await _tokenStorage.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));
      return _handleResponse(res);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(500, 'Connection failed or timed out. Please try again.');
    }
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool auth = true}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(auth: auth),
        body: jsonEncode(body ?? {}),
      ).timeout(const Duration(seconds: 15));
      return _handleResponse(res);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(500, 'Connection failed or timed out. Please try again.');
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));
      return _handleResponse(res);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(500, 'Connection failed or timed out. Please try again.');
    }
  }

  dynamic _handleResponse(http.Response res) {
    final decoded = res.body.isNotEmpty ? jsonDecode(res.body) : {};

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    final message = decoded is Map && decoded['message'] != null
        ? decoded['message'] as String
        : 'Something went wrong (${res.statusCode})';
        
    if (res.statusCode == 502 || (decoded is Map && decoded['error'] == 'stream_unavailable')) {
      throw StreamUnavailableException(res.statusCode, message);
    }
    
    throw ApiException(res.statusCode, message);
  }
}

class StreamUnavailableException extends ApiException {
  StreamUnavailableException(super.statusCode, super.message);
}
