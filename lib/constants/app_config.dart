import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.trim().isNotEmpty) {
      return _configuredApiBaseUrl.trim();
    }

    if (kIsWeb) {
      final browserUri = Uri.base;
      final host = browserUri.host.isEmpty ? '127.0.0.1' : browserUri.host;
      final scheme = browserUri.scheme == 'https' ? 'https' : 'http';

      return Uri(
        scheme: scheme,
        host: host,
        port: 8000,
        path: '/api',
      ).toString();
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.10.188.166:8000/api';
    }

    return 'http://127.0.0.1:8000/api';
  }
}
