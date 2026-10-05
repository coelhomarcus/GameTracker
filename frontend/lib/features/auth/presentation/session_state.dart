import '../data/auth_models.dart';

sealed class SessionState {
  const SessionState();
}

/// Restaurando a sessão guardada.
class SessionInitializing extends SessionState {
  const SessionInitializing();
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.user);
  final AuthUser user;
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

/// Há credenciais guardadas, mas o servidor não respondeu. Pede nova tentativa
/// em vez de forçar logout.
class SessionRestoreUnavailable extends SessionState {
  const SessionRestoreUnavailable();
}
