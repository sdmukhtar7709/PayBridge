import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AgentProfileData {
  final String name;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? address;
  final String? profileImage;
  final String? locationName;
  final num? cashLimit;
  final bool? isVerified;
  final bool? available;

  AgentProfileData({
    required this.name,
    this.firstName,
    this.lastName,
    this.phone,
    this.address,
    this.profileImage,
    this.locationName,
    this.cashLimit,
    this.isVerified,
    this.available,
  });

  factory AgentProfileData.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final agent = (json['agentProfile'] is Map<String, dynamic>)
        ? json['agentProfile'] as Map<String, dynamic>
        : <String, dynamic>{};

    final firstName = user['firstName'] as String?;
    final lastName = user['lastName'] as String?;
    final fullName = ((user['name'] as String?) ?? '').trim();
    final computed = [firstName, lastName]
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(' ');

    return AgentProfileData(
      name: fullName.isNotEmpty ? fullName : (computed.isNotEmpty ? computed : 'Agent'),
      firstName: firstName,
      lastName: lastName,
      phone: user['phone'] as String?,
      address: user['address'] as String?,
      profileImage: user['profileImage'] as String?,
      locationName: agent['locationName'] as String?,
      cashLimit: _toNum(agent['cashLimit']),
      isVerified: agent['isVerified'] as bool?,
      available: agent['available'] as bool?,
    );
  }

  static num? _toNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'user': {
        'name': name,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'address': address,
        'profileImage': profileImage,
      },
      'agentProfile': {
        'locationName': locationName,
        'cashLimit': cashLimit,
        'isVerified': isVerified,
        'available': available,
      }
    };
  }
}

class AgentAuthResult {
  final String token;
  final AgentProfileData? profile;

  AgentAuthResult({required this.token, this.profile});

  factory AgentAuthResult.fromJson(Map<String, dynamic> json) {
    return AgentAuthResult(
      token: (json['token'] ?? '') as String,
      profile: AgentProfileData.fromJson(json),
    );
  }
}

class AgentService {
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.108:4002',
  );

  static const String _registerPath = '$_apiBaseUrl/register-agent';
  static const String _loginPath = '$_apiBaseUrl/login-agent';
  static const String _agentProfilePath = '$_apiBaseUrl/agent/profile';
  static const String _userProfilePath = '$_apiBaseUrl/user/profile';
  static const String _agentTokenKey = 'agent_auth_token';
  static const String _cachedAgentProfileKey = 'cached_agent_profile';

  static Future<AgentAuthResult> registerAgent({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String gender,
    required String maritalStatus,
    required int age,
    required String address,
    required String shopName,
    required double cashLimit,
    String? profileImage,
  }) async {
    final payload = {
      'email': email,
      'password': password,
      'name': '$firstName $lastName'.trim(),
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'gender': gender,
      'maritalStatus': maritalStatus,
      'age': age,
      'address': address,
      'profileImage': profileImage,
      'locationName': shopName.isNotEmpty ? shopName : address,
      'cashLimit': cashLimit,
    };

    final body = await _post(_registerPath, payload);
    final result = AgentAuthResult.fromJson(body);
    await _saveToken(result.token);
    if (result.profile != null) {
      await _cacheProfile(result.profile!);
    }
    return result;
  }

  static Future<AgentAuthResult> loginAgent({
    required String email,
    required String password,
  }) async {
    final body = await _post(_loginPath, {
      'email': email,
      'password': password,
    });
    final result = AgentAuthResult.fromJson(body);
    await _saveToken(result.token);
    if (result.profile != null) {
      await _cacheProfile(result.profile!);
    }
    return result;
  }

  static Future<AgentProfileData> getProfile() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Agent is not logged in');
    }

    final response = await http.get(
      Uri.parse(_agentProfilePath),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final profile = AgentProfileData.fromJson(body);
      await _cacheProfile(profile);
      return profile;
    }

    throw Exception(body['error'] ?? 'Failed to load agent profile');
  }

  static Future<void> updatePersonalProfile(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Agent is not logged in');
    }

    final response = await http.put(
      Uri.parse(_userProfilePath),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final cached = await getCachedProfile();
      final updated = AgentProfileData(
        name: [body['firstName'] as String?, body['lastName'] as String?]
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .join(' ')
            .trim()
            .isNotEmpty
            ? [body['firstName'] as String?, body['lastName'] as String?]
                .whereType<String>()
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .join(' ')
            : (cached?.name ?? 'Agent'),
        firstName: body['firstName'] as String?,
        lastName: body['lastName'] as String?,
        phone: body['phone'] as String?,
        address: body['address'] as String?,
        profileImage: body['profileImage'] as String?,
        locationName: cached?.locationName,
        cashLimit: cached?.cashLimit,
        isVerified: cached?.isVerified,
        available: cached?.available,
      );
      await _cacheProfile(updated);
      return;
    }

    throw Exception(body['error'] ?? 'Failed to update agent profile');
  }

  static Future<void> updateAgentLocation({
    required String locationName,
    required double latitude,
    required double longitude,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Agent is not logged in');
    }

    final response = await http.patch(
      Uri.parse(_agentProfilePath),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'locationName': locationName,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final cached = await getCachedProfile();
      if (cached == null) return;
      final updated = AgentProfileData(
        name: cached.name,
        firstName: cached.firstName,
        lastName: cached.lastName,
        phone: cached.phone,
        address: cached.address,
        profileImage: cached.profileImage,
        locationName: (body['locationName'] as String?) ?? locationName,
        cashLimit: cached.cashLimit,
        isVerified: cached.isVerified,
        available: cached.available,
      );
      await _cacheProfile(updated);
      return;
    }

    throw Exception(body['error'] ?? 'Failed to update agent location');
  }

  static Future<AgentProfileData?> getCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedAgentProfileKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AgentProfileData.fromJson(map);
    } catch (_) {
      await prefs.remove(_cachedAgentProfileKey);
      return null;
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_agentTokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_agentTokenKey);
    await prefs.remove(_cachedAgentProfileKey);
  }

  static Future<Map<String, dynamic>> _post(
    String url,
    Map<String, dynamic> payload,
  ) async {
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
    await prefs.setString(_agentTokenKey, token);
  }

  static Future<void> _cacheProfile(AgentProfileData profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedAgentProfileKey, jsonEncode(profile.toJson()));
  }
}
