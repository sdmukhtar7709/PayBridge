import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.57.70.152:4000',
  );
  static const String _authPath = '$_apiBaseUrl/auth';
  static const String _tokenKey = 'auth_token';

  static Future<AuthResult> register(String email, String password) async {
    final res = await _post(
      '$_authPath/register',
      {
        'email': email,
        'password': password,
      },
    );
    final result = AuthResult.fromJson(res);
    await _saveToken(result.token);
    return result;
  }

  static Future<AuthResult> login(String email, String password) async {
    final res = await _post(
      '$_authPath/login',
      {
        'email': email,
        'password': password,
      },
    );
    final result = AuthResult.fromJson(res);
    await _saveToken(result.token);
    return result;
  }

  static Future<String?> getToken() async {
    return _getToken();
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // --- internals ---
  static Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw Exception(body['error'] ?? 'Request failed');
  }

  static Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'error': 'Invalid server response'};
    }
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
}

class AuthResult {
  final String token;
  final AuthUser user;

  AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final token = (json['token'] ?? json['accessToken'] ?? '') as String;
    return AuthResult(
      token: token,
      user: AuthUser.fromJson((json['user'] ?? <String, dynamic>{}) as Map<String, dynamic>),
    );
  }
}

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String? role;

  AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] ?? json['_id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      role: json['role'] as String?,
    );
  }
}
