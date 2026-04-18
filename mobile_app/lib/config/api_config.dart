import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _androidUsbDefault = 'http://127.0.0.1:4000';
  static const String _androidUsbFallback = 'http://127.0.0.1:4001';

  static List<String> get candidateBaseUrls {
    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return [envUrl];
    }

    if (kIsWeb) {
      return const ['http://localhost:4000', 'http://localhost:4001'];
    }

    if (Platform.isAndroid) {
      // Physical Android over USB should use adb reverse + loopback.
      return const [_androidUsbDefault, _androidUsbFallback];
    }

    return const ['http://localhost:4000', 'http://localhost:4001'];
  }

  static String get baseUrl {
    return candidateBaseUrls.first;
  }
}
