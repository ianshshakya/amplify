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
/// IMPORTANT: update [baseUrl] to point at your running backend.
/// - Android emulator talking to a backend on your own machine: 10.0.2.2
/// - iOS simulator: localhost works directly
/// - Physical device: use your machine's LAN IP, e.g. http://192.168.1.5:5000
/// - Deployed backend (Render/Railway): use that public URL instead
class ApiClient {
  static const String baseUrl = 'https://amplify-ycmb.onrender.com/api';

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
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool auth = true}) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body ?? {}),
    );
    return _handleResponse(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _handleResponse(res);
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
