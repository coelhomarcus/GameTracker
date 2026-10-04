import 'dart:async';

import '../storage/token_store.dart';
import 'app_exception.dart';

class SessionTokens {
  const SessionTokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

typedef RefreshCall = Future<SessionTokens> Function(String refreshToken);

enum RefreshOutcome {
  /// Novos tokens foram aplicados.
  refreshed,

  /// O servidor recusou o refresh token: a sessão acabou e os dados locais foram limpos.
  invalid,

  /// Não foi possível renovar agora (rede/servidor); credenciais preservadas.
  unavailable,

  /// A sessão mudou (logout/troca de conta) durante a renovação; resultado descartado.
  discarded,

  /// Não há refresh token guardado.
  noSession,
}

/// Dono dos tokens da sessão atual.
///
/// - Uma única renovação em andamento: vários 401 aguardam o mesmo resultado.
/// - [generation] muda a cada logout/troca de conta. Um refresh ou uma resposta
///   que termina depois disso é descartado e não restaura a conta anterior.
class SessionManager {
  SessionManager({required this._store, required this._refreshCall});

  final TokenStore _store;
  final RefreshCall _refreshCall;

  String? _accessToken;
  Future<RefreshOutcome>? _inFlight;
  int _generation = 0;

  /// Chamado quando o servidor invalida a sessão (refresh recusado).
  void Function()? onExpired;

  String? get accessToken => _accessToken;
  int get generation => _generation;
  bool get hasAccessToken => _accessToken != null;

  /// Aplica uma sessão recém-obtida por login/cadastro.
  Future<void> start(SessionTokens tokens) async {
    _generation++;
    _inFlight = null;
    _accessToken = tokens.accessToken;
    await _store.write(tokens.refreshToken);
  }

  /// Tenta restaurar a sessão guardada (bootstrap).
  Future<RefreshOutcome> restore() => _refresh();

  /// Chamado ao receber 401. [usedToken] é o access token da requisição que falhou:
  /// se já mudou, outra requisição renovou e basta repetir com o token atual.
  Future<RefreshOutcome> refreshAfterUnauthorized(String? usedToken) {
    final current = _accessToken;
    if (current != null && current != usedToken) {
      return Future.value(RefreshOutcome.refreshed);
    }
    return _refresh();
  }

  Future<RefreshOutcome> _refresh() =>
      _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);

  Future<RefreshOutcome> _doRefresh() async {
    final generation = _generation;
    final refreshToken = await _store.read();
    if (generation != _generation) return RefreshOutcome.discarded;
    if (refreshToken == null) return RefreshOutcome.noSession;

    try {
      final tokens = await _refreshCall(refreshToken);
      if (generation != _generation) return RefreshOutcome.discarded;
      _accessToken = tokens.accessToken;
      await _store.write(tokens.refreshToken);
      return RefreshOutcome.refreshed;
    } on ApiException catch (e) {
      if (generation != _generation) return RefreshOutcome.discarded;
      if (e.isUnauthorized || e.status == 400) {
        await clear();
        onExpired?.call();
        return RefreshOutcome.invalid;
      }
      return RefreshOutcome.unavailable;
    } on NetworkException {
      return generation == _generation
          ? RefreshOutcome.unavailable
          : RefreshOutcome.discarded;
    } on CancelledException {
      return RefreshOutcome.discarded;
    }
  }

  /// Encerra a sessão local, mesmo sem rede. Retorna o refresh token que existia,
  /// para o chamador tentar revogá-lo no servidor.
  Future<String?> clear() async {
    final previous = await _store.read();
    _generation++;
    _inFlight = null;
    _accessToken = null;
    await _store.clear();
    return previous;
  }
}
