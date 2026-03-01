import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  static const String _apiBaseUrl = ApiConfig.baseUrl;
  static const String _authPath = '$_apiBaseUrl/auth';
  static const String _tokenKey = 'auth_token';

  static Future<AuthResult> register(String email, String password) async {
    final res = await _postAny(
      _candidateAuthUrls('/register'),
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
    final res = await _postAny(
      _candidateAuthUrls('/login'),
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
  static List<String> _candidateAuthUrls(String path) {
    return <String>['$_authPath$path'];
  }

  static Future<Map<String, dynamic>> _postAny(
    List<String> urls,
    Map<String, dynamic> payload,
  ) async {
    Object? lastError;
    for (final url in urls) {
      try {
        return await _post(url, payload);
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? Exception('Request failed');
  }

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
    final token = _readString(json['token'])
        .isNotEmpty
        ? _readString(json['token'])
        : _readString(json['accessToken']);
    return AuthResult(
      token: token,
      user: AuthUser.fromJson((json['user'] ?? <String, dynamic>{}) as Map<String, dynamic>),
    );
  }
}

String _readString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
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
      id: _readString(json['id']).isNotEmpty
          ? _readString(json['id'])
          : _readString(json['_id']),
      name: _readString(json['name']),
      email: _readString(json['email']),
      role: _readString(json['role']).isEmpty ? null : _readString(json['role']),
    );
  }
}
