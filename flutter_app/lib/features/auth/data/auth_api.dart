import 'package:dio/dio.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/session_manager.dart';
import 'auth_models.dart';

class AuthResult {
  const AuthResult({required this.user, required this.tokens});
  final AuthUser user;
  final SessionTokens tokens;
}

SessionTokens _tokens(Map<String, dynamic> json) => SessionTokens(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
);

/// Rotas `/auth/*`. Usa o cliente sem Bearer e sem refresh automático.
class AuthApi {
  AuthApi(this._dio);
  final Dio _dio;

  Future<AuthResult> login(String identifier, String password) =>
      guardApi(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'identifier': identifier, 'password': password},
        );
        return AuthResult(
          user: AuthUser.fromJson(r.data!['user'] as Map<String, dynamic>),
          tokens: _tokens(r.data!),
        );
      });

  Future<AuthResult> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) => guardApi(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
      },
    );
    return AuthResult(
      user: AuthUser.fromJson(r.data!['user'] as Map<String, dynamic>),
      tokens: _tokens(r.data!),
    );
  });

  Future<SessionTokens> refresh(String refreshToken) => guardApi(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return _tokens(r.data!);
  });

  Future<void> logout(String refreshToken) => guardApi(() async {
    await _dio.post<void>('/auth/logout', data: {'refreshToken': refreshToken});
  });
}
