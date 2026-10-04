import 'package:dio/dio.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/session_manager.dart';
import 'auth_api.dart';
import 'auth_models.dart';

sealed class RestoreResult {
  const RestoreResult();
}

class Restored extends RestoreResult {
  const Restored(this.user);
  final AuthUser user;
}

/// Não há sessão (sem token, token revogado ou expirado).
class SignedOut extends RestoreResult {
  const SignedOut();
}

/// Não deu para confirmar a sessão agora (rede/servidor). Credenciais preservadas.
class RestoreUnavailable extends RestoreResult {
  const RestoreUnavailable();
}

abstract interface class AuthRepository {
  Future<AuthUser> login(String identifier, String password);
  Future<AuthUser> register({
    required String name,
    required String username,
    required String email,
    required String password,
  });
  Future<RestoreResult> restore();

  /// Encerra a sessão local imediatamente; a revogação remota é best-effort.
  Future<void> logout();
}

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required this._api,
    required this._session,
    required this._apiDio,
  });

  final AuthApi _api;
  final SessionManager _session;

  /// Cliente autenticado, usado para `GET /auth/me`.
  final Dio _apiDio;

  @override
  Future<AuthUser> login(String identifier, String password) async {
    final result = await _api.login(identifier, password);
    await _session.start(result.tokens);
    return result.user;
  }

  @override
  Future<AuthUser> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final result = await _api.register(
      name: name,
      username: username,
      email: email,
      password: password,
    );
    await _session.start(result.tokens);
    return result.user;
  }

  @override
  Future<RestoreResult> restore() async {
    final outcome = await _session.restore();
    switch (outcome) {
      case RefreshOutcome.noSession:
      case RefreshOutcome.invalid:
      case RefreshOutcome.discarded:
        return const SignedOut();
      case RefreshOutcome.unavailable:
        return const RestoreUnavailable();
      case RefreshOutcome.refreshed:
        try {
          final user = await guardApi(() async {
            final r = await _apiDio.get<Map<String, dynamic>>('/auth/me');
            return AuthUser.fromJson(r.data!);
          });
          return Restored(user);
        } on ApiException catch (e) {
          // 401/404 após um refresh bem-sucedido: a conta não existe mais.
          if (e.isUnauthorized || e.status == 404) {
            await _session.clear();
            return const SignedOut();
          }
          return const RestoreUnavailable();
        } on NetworkException {
          return const RestoreUnavailable();
        } on CancelledException {
          return const SignedOut();
        }
    }
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _session.clear();
    if (refreshToken == null) return;
    // Sem await de propósito: sem rede, o logout local já aconteceu.
    _api.logout(refreshToken).catchError((Object _) {});
  }
}
