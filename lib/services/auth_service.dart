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
  static const _roleKey = 'user_role';

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (e) {
      debugPrint('Failed to save session token: $e');
    }
  }

  Future<void> saveRole(String role) async {
    try {
      await _storage.write(key: _roleKey, value: role);
    } catch (e) {
      debugPrint('Failed to save user role: $e');
    }
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<String?> getRole() => _storage.read(key: _roleKey);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<void> clearRole() => _storage.delete(key: _roleKey);

  /// Fetches the signed-in user's role from the backend
  /// (GET /api/userinfo?token=...). Returns null if the request fails or
  /// the response doesn't expose a role (either `role` or `user_role`).
  Future<String?> fetchUserRole(String token) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/userinfo').replace(
        queryParameters: {'token': token},
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>
            : <String, dynamic>{};
        return (body['role'] ?? body['user_role']) as String?;
      }
    } catch (e) {
      debugPrint('Failed to fetch user role: $e');
    }
    return null;
  }

  /// Returns `true` if the session is valid and stores the role from the
  /// session response so callers can check [getRole] afterwards.
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
        if (body['valid'] == true) {
          // Persist the role returned by the session endpoint so the app
          // can route to the correct home screen without another round-trip.
          // If the session endpoint doesn't include it, fall back to the
          // userinfo endpoint.
          var role = body['role'] as String?;
          role ??= await fetchUserRole(token);
          if (role != null) await saveRole(role);
          return true;
        }
      }

      // Token rejected or endpoint missing — clear stale token + role.
      await clearToken();
      await clearRole();
      return false;
    } catch (e) {
      debugPrint('Session check — error: $e');
      // Network error — treat as no session so the user can log in.
      return false;
    }
  }

  }
