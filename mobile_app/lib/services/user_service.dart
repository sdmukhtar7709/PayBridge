import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'auth_service.dart';

class User {
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? gender;
  final String? maritalStatus;
  final int? age;
  final String? address;
  final String? city;
  final String? profileImage;

  User({
    this.firstName,
    this.lastName,
    this.phone,
    this.gender,
    this.maritalStatus,
    this.age,
    this.address,
    this.city,
    this.profileImage,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      phone: json['phone'] as String?,
      gender: json['gender'] as String?,
      maritalStatus: json['maritalStatus'] as String?,
      age: json['age'] as int?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      profileImage: json['profileImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'gender': gender,
      'maritalStatus': maritalStatus,
      'age': age,
      'address': address,
      'city': city,
      'profileImage': profileImage,
    };
  }

  String get displayName {
    final fullName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return fullName;
  }
}

class UserService {
  static final String _apiBaseUrl = ApiConfig.baseUrl;
  static final String _profilePath = '$_apiBaseUrl/user/profile';
  static const String _cachedProfileKey = 'cached_user_profile';
  static const Duration _requestTimeout = Duration(seconds: 60);
  static const int _maxTransientRetries = 1;

  Future<User> getProfile() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in');
    }

    final response = await _sendRequest(
      () => http.get(
        Uri.parse(_profilePath),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final body = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['error'] ?? 'Failed to load profile');
    }

    final profile = User.fromJson(body);
    await _cacheProfile(profile);
    return profile;
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in');
    }

    final response = await _sendRequest(
      () => http.put(
        Uri.parse(_profilePath),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ),
    );

    final body = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['error'] ?? 'Failed to update profile');
    }

    await _cacheProfile(User.fromJson(body));
  }

  Future<User?> getCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedProfileKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return User.fromJson(map);
    } catch (_) {
      await prefs.remove(_cachedProfileKey);
      return null;
    }
  }

  Future<void> _cacheProfile(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedProfileKey, jsonEncode(user.toJson()));
  }

  Future<http.Response> _sendRequest(Future<http.Response> Function() request) async {
    for (var attempt = 0; attempt <= _maxTransientRetries; attempt++) {
      try {
        return await request().timeout(_requestTimeout);
      } on TimeoutException {
        if (attempt < _maxTransientRetries) {
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }
        throw Exception('Request timed out. Please try again.');
      } on SocketException {
        if (attempt < _maxTransientRetries) {
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }
        throw Exception('Cannot reach server. Please check your internet connection and DNS settings.');
      } on HandshakeException {
        throw Exception('Secure connection failed. Please verify your device date/time and HTTPS connectivity.');
      } on http.ClientException {
        if (attempt < _maxTransientRetries) {
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }
        throw Exception('Network client error. Please try again.');
      }
    }

    throw Exception('Network request failed.');
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'error': 'Invalid server response'};
    }
  }
}
