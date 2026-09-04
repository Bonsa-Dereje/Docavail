import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const String _apiBaseUrl = 'https://docavail-endpoints.vercel.app/api';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();
  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'session_token';

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (e) {
      debugPrint('Failed to save session token: $e');
    }
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  /// Checks whether a stored session token is still valid on the backend.
  /// Returns `true` if the server confirms the token, `false` otherwise.
  Future<bool> hasValidSession() async {
    final token = await getToken();
    debugPrint('Session check — stored token: ${token != null ? "${token.substring(0, 8)}..." : "null"}');
    if (token == null) return false;

    try {
      final uri = Uri.parse('$_apiBaseUrl/session?token=$token');
      debugPrint('Session check — calling $uri');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));

      debugPrint('Session check — status ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final body = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>
            : <String, dynamic>{};
        if (body['valid'] == true) return true;
      }

      // Token rejected or endpoint missing — clear stale token.
      await clearToken();
      return false;
    } catch (e) {
      debugPrint('Session check — error: $e');
      // Network error — treat as no session so the user can log in.
      return false;
    }
  }
}
