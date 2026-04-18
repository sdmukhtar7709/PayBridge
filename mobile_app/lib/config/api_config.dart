class ApiConfig {
  static const String _productionBaseUrl = 'https://cashio-backends.onrender.com';

  static List<String> get candidateBaseUrls {
    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return [_normalizeBaseUrl(envUrl)];
    }

    return const [_productionBaseUrl];
  }

  static String get baseUrl {
    return candidateBaseUrls.first;
  }

  static String _normalizeBaseUrl(String value) {
    var normalized = value.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    // Force HTTPS for internet-facing deployments.
    if (normalized.startsWith('http://')) {
      normalized = 'https://${normalized.substring('http://'.length)}';
    }

    return normalized;
  }
}
