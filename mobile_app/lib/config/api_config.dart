import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:4000';
    }

    if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to reach the host machine.
      return 'http://10.0.2.2:4000';
    }

    return 'http://localhost:4000';
  }
}
