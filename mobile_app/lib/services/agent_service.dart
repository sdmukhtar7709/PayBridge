import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AgentProfileData {
  final String name;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? gender;
  final String? maritalStatus;
  final int? age;
  final String? address;
  final String? profileImage;
  final String? locationName;
  final String? city;
  final double? latitude;
  final double? longitude;
  final num? cashLimit;
  final bool? isVerified;
  final bool? isBanned;
  final bool? available;
  final int ratingSum;
  final int ratingCount;

  AgentProfileData({
    required this.name,
    this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.gender,
    this.maritalStatus,
    this.age,
    this.address,
    this.profileImage,
    this.locationName,
    this.city,
    this.latitude,
    this.longitude,
    this.cashLimit,
    this.isVerified,
    this.isBanned,
    this.available,
    this.ratingSum = 0,
    this.ratingCount = 0,
  });

  double? get averageRating {
    if (ratingCount <= 0) return null;
    return ratingSum / ratingCount;
  }

  factory AgentProfileData.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final agent = (json['agentProfile'] is Map<String, dynamic>)
        ? json['agentProfile'] as Map<String, dynamic>
        : <String, dynamic>{};

    final firstName = _toNullableString(user['firstName']);
    final lastName = _toNullableString(user['lastName']);
    final fullName = _toStringValue(user['name']).trim();
    final computed = [firstName, lastName]
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(' ');

    return AgentProfileData(
      name: fullName.isNotEmpty ? fullName : (computed.isNotEmpty ? computed : 'Agent'),
      email: _toNullableString(user['email']),
      firstName: firstName,
      lastName: lastName,
      phone: _toNullableString(user['phone']),
      gender: _toNullableString(user['gender']),
      maritalStatus: _toNullableString(user['maritalStatus']),
      age: _toInt(user['age']),
      address: _toNullableString(user['address']),
      profileImage: _toNullableString(user['profileImage']),
      locationName: _toNullableString(agent['locationName']),
      city: _toNullableString(agent['city']),
      latitude: _toDouble(agent['latitude']),
      longitude: _toDouble(agent['longitude']),
      cashLimit: _toNum(agent['cashLimit']),
      isVerified: agent['isVerified'] as bool?,
      isBanned: agent['isBanned'] as bool?,
      available: agent['available'] as bool?,
      ratingSum: _toInt(agent['ratingSum']) ?? 0,
      ratingCount: _toInt(agent['ratingCount']) ?? 0,
    );
  }

  static num? _toNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  static String _toStringValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static String? _toNullableString(dynamic value) {
    final text = _toStringValue(value).trim();
    return text.isEmpty ? null : text;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'user': {
        'name': name,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'gender': gender,
        'maritalStatus': maritalStatus,
        'age': age,
        'address': address,
        'profileImage': profileImage,
      },
      'agentProfile': {
        'locationName': locationName,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'cashLimit': cashLimit,
        'isVerified': isVerified,
        'isBanned': isBanned,
        'available': available,
        'ratingSum': ratingSum,
        'ratingCount': ratingCount,
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
      token: AgentProfileData._toStringValue(json['token']),
      profile: AgentProfileData.fromJson(json),
    );
  }
}

class AgentLiveRequest {
  final String id;
  final String name;
  final String location;
  final String city;
  final String email;
  final String phone;
  final String address;
  final int amount;
  final int agentCommission;
  final int totalPaid;
  final int agentReceived;
  final String status;
  final String type;
  final String agentConfirmOtp;
  final DateTime? approvedAt;
  final DateTime? userConfirmedAt;
  final DateTime? agentConfirmedAt;

  const AgentLiveRequest({
    required this.id,
    required this.name,
    required this.location,
    required this.city,
    required this.email,
    required this.phone,
    required this.address,
    required this.amount,
    this.agentCommission = 0,
    this.totalPaid = 0,
    this.agentReceived = 0,
    required this.status,
    this.type = 'Cash to UPI',
    this.agentConfirmOtp = '',
    this.approvedAt,
    this.userConfirmedAt,
    this.agentConfirmedAt,
  });

  factory AgentLiveRequest.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};

    final address = AgentProfileData._toStringValue(user['address']).trim();
    final location = address.isNotEmpty ? address : 'Unknown area';
    final city = AgentProfileData._toStringValue(user['city']).trim();
    final email = AgentProfileData._toStringValue(user['email']).trim();
    final phone = AgentProfileData._toStringValue(user['phone']).trim();

    return AgentLiveRequest(
      id: (json['id'] ?? '').toString(),
        name: AgentProfileData._toStringValue(user['name']).trim().isNotEmpty
          ? AgentProfileData._toStringValue(user['name']).trim()
          : 'User',
      location: location,
      city: city,
      email: email,
      phone: phone,
      address: address,
      amount: AgentProfileData._toInt(json['amount']) ?? 0,
        agentCommission: AgentProfileData._toInt(json['agentCommission']) ?? 0,
        totalPaid:
          AgentProfileData._toInt(json['totalPaid']) ?? (AgentProfileData._toInt(json['amount']) ?? 0),
        agentReceived: AgentProfileData._toInt(json['agentReceived']) ??
          (AgentProfileData._toInt(json['totalPaid']) ?? (AgentProfileData._toInt(json['amount']) ?? 0)),
      status: AgentProfileData._toStringValue(json['status']).trim().isNotEmpty
          ? AgentProfileData._toStringValue(json['status']).trim()
          : 'pending',
        type: AgentProfileData._toStringValue(json['requestType']).trim().isNotEmpty
          ? AgentProfileData._toStringValue(json['requestType']).trim()
          : 'Cash to UPI',
        agentConfirmOtp: AgentProfileData._toStringValue(json['agentConfirmOtp']).trim(),
        approvedAt: DateTime.tryParse((json['approvedAt'] ?? '').toString()),
        userConfirmedAt: DateTime.tryParse((json['userConfirmedAt'] ?? '').toString()),
        agentConfirmedAt: DateTime.tryParse((json['agentConfirmedAt'] ?? '').toString()),
    );
  }

  AgentLiveRequest copyWith({
    String? status,
    String? agentConfirmOtp,
    DateTime? approvedAt,
    DateTime? userConfirmedAt,
    DateTime? agentConfirmedAt,
  }) {
    return AgentLiveRequest(
      id: id,
      name: name,
      location: location,
      city: city,
      email: email,
      phone: phone,
      address: address,
      amount: amount,
      agentCommission: agentCommission,
      totalPaid: totalPaid,
      agentReceived: agentReceived,
      status: status ?? this.status,
      type: type,
      agentConfirmOtp: agentConfirmOtp ?? this.agentConfirmOtp,
      approvedAt: approvedAt ?? this.approvedAt,
      userConfirmedAt: userConfirmedAt ?? this.userConfirmedAt,
      agentConfirmedAt: agentConfirmedAt ?? this.agentConfirmedAt,
    );
  }
}

class AgentTransactionHistoryItem {
  final String id;
  final String status;
  final int amount;
  final int agentCommission;
  final int totalPaid;
  final int agentReceived;
  final String requestType;
  final String userId;
  final String userName;
  final String userPhone;
  final String userEmail;
  final String userAddress;
  final String userCity;
  final DateTime? approvedAt;
  final DateTime? userConfirmedAt;
  final DateTime? agentConfirmedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  const AgentTransactionHistoryItem({
    required this.id,
    required this.status,
    required this.amount,
    required this.agentCommission,
    required this.totalPaid,
    required this.agentReceived,
    required this.requestType,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.userEmail,
    required this.userAddress,
    required this.userCity,
    this.approvedAt,
    this.userConfirmedAt,
    this.agentConfirmedAt,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  factory AgentTransactionHistoryItem.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AgentTransactionHistoryItem(
      id: (json['id'] ?? '').toString(),
      status: AgentProfileData._toStringValue(json['status']).trim().toLowerCase(),
      amount: AgentProfileData._toInt(json['amount']) ?? 0,
      agentCommission: AgentProfileData._toInt(json['agentCommission']) ?? 0,
      totalPaid:
          AgentProfileData._toInt(json['totalPaid']) ?? (AgentProfileData._toInt(json['amount']) ?? 0),
      agentReceived: AgentProfileData._toInt(json['agentReceived']) ??
          (AgentProfileData._toInt(json['totalPaid']) ?? (AgentProfileData._toInt(json['amount']) ?? 0)),
        requestType: AgentProfileData._toStringValue(json['requestType']).trim().isEmpty
          ? 'Cash to UPI'
          : AgentProfileData._toStringValue(json['requestType']).trim(),
      userId: AgentProfileData._toStringValue(json['userId']).trim(),
      userName: AgentProfileData._toStringValue(user['name']).trim().isEmpty
          ? 'User'
          : AgentProfileData._toStringValue(user['name']).trim(),
      userPhone: AgentProfileData._toStringValue(user['phone']).trim(),
      userEmail: AgentProfileData._toStringValue(user['email']).trim(),
      userAddress: AgentProfileData._toStringValue(user['address']).trim(),
      userCity: AgentProfileData._toStringValue(user['city']).trim(),
      approvedAt: DateTime.tryParse((json['approvedAt'] ?? '').toString()),
      userConfirmedAt: DateTime.tryParse((json['userConfirmedAt'] ?? '').toString()),
      agentConfirmedAt: DateTime.tryParse((json['agentConfirmedAt'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()),
      completedAt: DateTime.tryParse((json['completedAt'] ?? '').toString()),
    );
  }
}

class AgentService {
  static final String _apiBaseUrl = ApiConfig.baseUrl;

  static final String _registerPath = '$_apiBaseUrl/register-agent';
  static final String _loginPath = '$_apiBaseUrl/login-agent';
  static final String _agentProfilePath = '$_apiBaseUrl/agent/profile';
  static final String _agentManageProfilePath = '$_apiBaseUrl/agent/profile/manage';
  static final String _agentLiveRequestsPath = '$_apiBaseUrl/agent/transactions/live-requests';
  static final String _agentHistoryPath = '$_apiBaseUrl/agent/transactions/history';
  static final String _transactionConfirmAgentPath = '$_apiBaseUrl/transactions/confirm-agent';
  static const String _agentTokenKey = 'agent_auth_token';
  static const String _cachedAgentProfileKey = 'cached_agent_profile';
  static const Duration _requestTimeout = Duration(seconds: 60);
  static const int _maxTransientRetries = 1;

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
    String? city,
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
      'city': city,
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
    await manageProfile(user: data);
  }

  /// PATCH any fields on agent profile (e.g. city, locationName, cashLimit, available).
  static Future<void> patchAgentProfile(Map<String, dynamic> data) async {
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
      body: jsonEncode(data),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final profile = AgentProfileData.fromJson(body);
      await _cacheProfile(profile);
      return;
    }
    throw Exception(_readError(body, 'Failed to patch agent profile'));
  }

  static Future<AgentProfileData> manageProfile({
    Map<String, dynamic>? user,
    Map<String, dynamic>? agentProfile,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Agent is not logged in');
    }

    final payload = <String, dynamic>{};
    if (user != null && user.isNotEmpty) payload['user'] = user;
    if (agentProfile != null && agentProfile.isNotEmpty) payload['agentProfile'] = agentProfile;

    final response = await http.patch(
      Uri.parse(_agentManageProfilePath),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final updated = AgentProfileData.fromJson(body);
      await _cacheProfile(updated);
      return updated;
    }

    throw Exception(_readError(body, 'Failed to update agent profile'));
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
      final updated = AgentProfileData.fromJson(body);
      await _cacheProfile(updated);
      return;
    }

    throw Exception(_readError(body, 'Failed to update agent location'));
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

  static Future<List<AgentLiveRequest>> getLiveRequests({int limit = 20}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Agent is not logged in');
    }

    final uri = Uri.parse(_agentLiveRequestsPath).replace(
      queryParameters: {'limit': '$limit'},
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final items = body['items'];
      if (items is List) {
        return items
            .whereType<Map<String, dynamic>>()
            .map(AgentLiveRequest.fromJson)
            .toList();
      }
      return const <AgentLiveRequest>[];
    }

    throw Exception(_readError(body, 'Failed to load live requests'));
  }

  static Future<List<AgentTransactionHistoryItem>> getTransactionHistory({int limit = 50}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Agent is not logged in');
    }

    final uri = Uri.parse(_agentHistoryPath).replace(
      queryParameters: {'limit': '$limit'},
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final items = body['items'];
      if (items is List) {
        return items
            .whereType<Map<String, dynamic>>()
            .map(AgentTransactionHistoryItem.fromJson)
            .toList();
      }
      return const <AgentTransactionHistoryItem>[];
    }

    throw Exception(_readError(body, 'Failed to load transaction history'));
  }

  static Future<void> rejectLiveRequest(String requestId) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Agent is not logged in');
    }

    final uri = Uri.parse('$_agentLiveRequestsPath/$requestId/reject');
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(_readError(body, 'Failed to reject request'));
  }

  static Future<void> archiveLiveRequest(String requestId) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Agent is not logged in');
    }

    final uri = Uri.parse('$_agentLiveRequestsPath/$requestId/archive');
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(_readError(body, 'Failed to archive request'));
  }

  static Future<int> clearAllRequests() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Agent is not logged in');
    }

    final uri = Uri.parse('$_apiBaseUrl/agent/transactions/requests/clear-all');
    final response = await http.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final deleted = body['deleted'];
      return deleted is int ? deleted : int.tryParse('$deleted') ?? 0;
    }

    throw Exception(_readError(body, 'Failed to clear requests'));
  }

  static Future<void> approveLiveRequest({
    required String requestId,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Agent is not logged in');
    }

    final uri = Uri.parse('$_agentLiveRequestsPath/$requestId/approve');
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(_readError(body, 'Failed to approve request'));
  }

  static Future<String?> verifyRequestOtp({
    required String requestId,
    required String otp,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Agent is not logged in');
    }

    final uri = Uri.parse('$_agentLiveRequestsPath/$requestId/verify-request-otp');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'otp': otp}),
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = body['agentConfirmOtp'];
      return raw is String ? raw : null;
    }

    throw Exception(_readError(body, 'Failed to verify OTP'));
  }

  static Future<String?> confirmWithUserOtp({
    required String transactionId,
    required String otp,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Agent is not logged in');
    }

    final response = await http.post(
      Uri.parse(_transactionConfirmAgentPath),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'transactionId': transactionId,
        'otp': otp,
      }),
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final status = body['status'];
      return status is String ? status : null;
    }

    throw Exception(_readError(body, 'Failed to verify OTP'));
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
    for (var attempt = 0; attempt <= _maxTransientRetries; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(_requestTimeout);

        final body = _decodeBody(response);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return body;
        }

        throw Exception(_readError(body, 'Request failed'));
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

    throw Exception('Request failed');
  }

  static Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'error': 'Invalid server response'};
    }
  }

  static String _readError(Map<String, dynamic> body, String fallback) {
    final error = body['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error;
    }
    if (error is Map<String, dynamic>) {
      final details = error['details'];
      if (details is List && details.isNotEmpty) {
        final first = details.first;
        if (first is Map<String, dynamic>) {
          final detailMessage = first['message'];
          if (detailMessage is String && detailMessage.trim().isNotEmpty) {
            return detailMessage;
          }
        }
      }
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return fallback;
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
