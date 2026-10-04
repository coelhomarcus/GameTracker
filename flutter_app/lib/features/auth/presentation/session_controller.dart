import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../push/application/push_controller.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import 'session_state.dart';

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    // Servidor recusou o refresh token durante o uso: volta ao login.
    final manager = ref.read(sessionManagerProvider);
    manager.onExpired = () => state = const SessionUnauthenticated();
    ref.onDispose(() => manager.onExpired = null);
    Future.microtask(bootstrap);
    return const SessionInitializing();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> bootstrap() async {
    state = const SessionInitializing();
    final result = await _repo.restore();
    state = switch (result) {
      Restored(:final user) => SessionAuthenticated(user),
      SignedOut() => const SessionUnauthenticated(),
      RestoreUnavailable() => const SessionRestoreUnavailable(),
    };
  }

  /// Lança [AppException] em falha; a tela decide a mensagem e mantém o formulário.
  Future<void> login(String identifier, String password) async {
    final user = await _repo.login(identifier, password);
    state = SessionAuthenticated(user);
  }

  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final user = await _repo.register(
      name: name,
      username: username,
      email: email,
      password: password,
    );
    state = SessionAuthenticated(user);
  }

  /// Relê a conta no servidor (depois de editar o perfil ou enviar uma foto). Devolve o usuário
  /// novo, ou `null` se a sessão mudou ou a consulta falhou: nesse caso o dado anterior fica.
  Future<AuthUser?> refreshUser() async {
    final current = state;
    if (current is! SessionAuthenticated) return null;
    try {
      final user = await _repo.me();
      // Logout ou troca de conta durante a consulta: não aplica o usuário a outra sessão.
      final now = state;
      if (now is! SessionAuthenticated || now.user.id != user.id) return null;
      state = SessionAuthenticated(user);
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    // Antes de encerrar a sessão: revogar o aparelho exige o token de acesso.
    await ref.read(pushUnregisterProvider)();
    await _repo.logout();
    state = const SessionUnauthenticated();
  }
}
