import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Simple auth helper to call the Node backend and keep the JWT.
/// Uses 10.0.2.2 for Android emulators; change to localhost when running Flutter web/desktop.
class AuthService {
  static const String _baseUrl = 'http://10.0.2.2:3000';
  static const String _authPath = '$_baseUrl/auth';
  static const String _tokenKey = 'auth_token';

  static Future<_AuthResult> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final res = await _post(
      '$_authPath/signup',
      {
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'password': password,
      },
    );
    final result = _AuthResult.fromJson(res);
    await _saveToken(result.token);
    return result;
  }

  static Future<_AuthResult> login({
    required String email,
    required String password,
  }) async {
    final res = await _post(
      '$_authPath/login',
      {
        'email': email,
        'password': password,
      },
    );
    final result = _AuthResult.fromJson(res);
    await _saveToken(result.token);
    return result;
  }

  static Future<_User?> fetchProfile() async {
    final token = await _getToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('$_authPath/me'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      // Clear bad token to avoid loops.
      await clearToken();
      throw Exception(body['error'] ?? 'Unable to load profile');
    }

    return _User.fromJson(body['user']);
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

class _AuthResult {
  final String token;
  final _User user;

  _AuthResult({required this.token, required this.user});

  factory _AuthResult.fromJson(Map<String, dynamic> json) {
    return _AuthResult(
      token: json['token'] as String,
      user: _User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class _User {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;

  _User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
  });

  factory _User.fromJson(Map<String, dynamic> json) {
    return _User(
      id: (json['id'] ?? json['_id'] ?? '') as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
    );
  }
}
