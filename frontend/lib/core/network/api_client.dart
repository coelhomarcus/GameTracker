import 'package:dio/dio.dart';

import 'api_config.dart';
import 'auth_interceptor.dart';
import 'session_manager.dart';

BaseOptions _baseOptions(String baseUrl) => BaseOptions(
  baseUrl: baseUrl,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 20),
  sendTimeout: const Duration(seconds: 20),
  headers: {'Accept': 'application/json'},
);

/// Cliente das rotas `/auth/*`: sem Bearer e sem refresh automático (não recursivo).
Dio createAuthDio({String? baseUrl}) {
  final dio = Dio(_baseOptions(baseUrl ?? ApiConfig.apiUrl));
  dio.options.extra[RequestFlags.skipAuth] = true;
  return dio;
}

/// Cliente das rotas de negócio, com autenticação e renovação de sessão.
Dio createApiDio(
  SessionManager session, {
  String? baseUrl,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(_baseOptions(baseUrl ?? ApiConfig.apiUrl));
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.add(AuthInterceptor(session: session, dio: dio));
  return dio;
}
