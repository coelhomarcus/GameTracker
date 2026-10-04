import 'package:flutter/foundation.dart';

/// URL da API. Valor público, definido no build: `--dart-define=API_URL=https://...`.
/// Sem o define, usa o backend local (no emulador Android, o host é 10.0.2.2).
abstract final class ApiConfig {
  static const _fromEnv = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3100';
    }
    return 'http://localhost:3100';
  }

  static String get apiUrl => '$baseUrl/api';
}
