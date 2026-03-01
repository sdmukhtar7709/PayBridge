import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RequestTypeStore {
  static const String _key = 'request_type_by_transaction_id';

  static Future<void> saveType({
    required String transactionId,
    required String requestType,
  }) async {
    if (transactionId.trim().isEmpty || requestType.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final map = await _readMap(prefs);
    map[transactionId] = requestType;
    await prefs.setString(_key, jsonEncode(map));
  }

  static Future<Map<String, String>> getTypeMap() async {
    final prefs = await SharedPreferences.getInstance();
    return _readMap(prefs);
  }

  static Future<Map<String, String>> _readMap(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String, String>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String, String>{};
      return decoded.map((key, value) => MapEntry(key, value?.toString() ?? ''));
    } catch (_) {
      return <String, String>{};
    }
  }
}
