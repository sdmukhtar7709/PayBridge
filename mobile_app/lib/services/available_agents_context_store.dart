import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AvailableAgentsContext {
  final String city;
  final double? latitude;
  final double? longitude;
  final double radiusKm;
  final String transactionType;
  final String amount;

  const AvailableAgentsContext({
    required this.city,
    this.latitude,
    this.longitude,
    required this.radiusKm,
    required this.transactionType,
    required this.amount,
  });

  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
      'transactionType': transactionType,
      'amount': amount,
    };
  }

  factory AvailableAgentsContext.fromJson(Map<String, dynamic> json) {
    return AvailableAgentsContext(
      city: (json['city'] ?? '').toString(),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      radiusKm: _toDouble(json['radiusKm']) ?? 10.0,
      transactionType: (json['transactionType'] ?? 'UPI → Cash').toString(),
      amount: (json['amount'] ?? '1000').toString(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class AvailableAgentsContextStore {
  static const String _key = 'last_available_agents_context';

  static Future<void> save(AvailableAgentsContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(context.toJson()));
  }

  static Future<AvailableAgentsContext?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AvailableAgentsContext.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
