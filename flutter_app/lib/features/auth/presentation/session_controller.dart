import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
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

  Future<void> logout() async {
    await _repo.logout();
    state = const SessionUnauthenticated();
  }
}
