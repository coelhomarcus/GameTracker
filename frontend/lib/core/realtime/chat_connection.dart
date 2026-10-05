import 'dart:async';
import 'dart:math' as math;

import 'chat_transport.dart';

enum ChatConnectionStatus {
  /// Não está tentando conectar (sem sessão ou parado de propósito).
  stopped,

  /// Abrindo uma conexão.
  connecting,

  /// Conectado e com as salas reentradas.
  connected,

  /// Aguardando para tentar de novo (backoff).
  waiting,
}

class ChatConnectionState {
  const ChatConnectionState(this.status, {this.attempt = 0});

  final ChatConnectionStatus status;

  /// Quantas tentativas seguidas falharam (0 quando conectado).
  final int attempt;

  bool get isConnected => status == ChatConnectionStatus.connected;
}

/// O que aconteceu ao tentar renovar a sessão depois de o servidor recusar o token.
enum TokenRefresh { refreshed, sessionEnded, unavailable }

/// 1 s, 2 s, 4 s, 8 s, 16 s e depois 30 s, com um pouco de variação para os aparelhos não
/// reconectarem todos ao mesmo tempo quando o servidor volta.
Duration defaultBackoff(int attempt) {
  final seconds = math.min(30, 1 << math.min(attempt, 5));
  final jitterMs = math.Random().nextInt(400);
  return Duration(seconds: seconds, milliseconds: jitterMs);
}

/// Mantém UMA conexão autenticada viva: reconecta sozinha depois de queda, suspensão ou reinício
/// do servidor, sempre com um token válido, e reentra nas salas das conversas abertas.
///
/// Não usa a reconexão automática do Socket.IO: ela reaproveitaria o token antigo (que expira em
/// 15 min) e não sabe quais salas reentrar.
class ChatConnection {
  ChatConnection({
    required this._transport,
    required this._accessToken,
    required this._refresh,
    this._backoff = defaultBackoff,
    this.joinTimeout = const Duration(seconds: 6),
  });

  final ChatTransport _transport;
  final Future<String?> Function() _accessToken;
  final Future<TokenRefresh> Function(String? usedToken) _refresh;
  final Duration Function(int attempt) _backoff;
  final Duration joinTimeout;

  final _states = StreamController<ChatConnectionState>.broadcast();
  final _resynced = StreamController<void>.broadcast();
  final _rooms = <String>{};

  ChatConnectionState _state = const ChatConnectionState(
    ChatConnectionStatus.stopped,
  );
  bool _running = false;
  int _runId = 0;
  void Function()? _wake;

  ChatConnectionState get state => _state;
  Stream<ChatConnectionState> get states => _states.stream;

  /// Dispara cada vez que a conexão (re)estabelece e as salas foram reentradas. As telas usam
  /// isto para buscar o que chegou durante a queda.
  Stream<void> get resynced => _resynced.stream;

  ChatTransport get transport => _transport;

  void _set(ChatConnectionStatus status, {int attempt = 0}) {
    _state = ChatConnectionState(status, attempt: attempt);
    if (!_states.isClosed) _states.add(_state);
  }

  /// Começa a conectar e a manter a conexão. Idempotente.
  void start() {
    if (_running) return;
    _running = true;
    final run = ++_runId;
    unawaited(_loop(run));
  }

  /// Para de vez (logout/troca de conta) e fecha o socket. As salas desejadas são esquecidas.
  Future<void> stop() async {
    _running = false;
    _runId++;
    _rooms.clear();
    _wake?.call();
    await _transport.disconnect();
    _set(ChatConnectionStatus.stopped);
  }

  /// Tenta agora (ao voltar para o app, ou no botão "Tentar de novo"): encurta a espera do
  /// backoff e, se a conexão estava parada, recomeça.
  void reconnectNow() {
    if (!_running) {
      start();
      return;
    }
    _wake?.call();
  }

  /// Ao voltar do segundo plano o sistema pode ter matado o socket sem avisar. Confere com um
  /// pedido leve; se não responder, derruba e reconecta.
  Future<void> verify() async {
    if (!_running) return;
    if (!_transport.isConnected) {
      reconnectNow();
      return;
    }
    final room = _rooms.isEmpty ? null : _rooms.first;
    if (room == null) return;
    try {
      await _transport.request('presence:get', {
        'conversationId': room,
      }, timeout: const Duration(seconds: 3));
    } on TransportException {
      await _transport.disconnect();
      reconnectNow();
    }
  }

  /// Registra a sala como desejada e, se conectado, entra nela. Devolve se o servidor aceitou.
  /// Sem conexão, a entrada acontece na próxima conexão.
  Future<bool> joinRoom(String conversationId) async {
    _rooms.add(conversationId);
    if (!_transport.isConnected) return false;
    try {
      return await _join(conversationId);
    } on TransportException {
      return false;
    }
  }

  void leaveRoom(String conversationId) {
    _rooms.remove(conversationId);
    _transport.send('conversation:leave', {'conversationId': conversationId});
  }

  Future<bool> _join(String conversationId) async {
    final response = await _transport.request('conversation:join', {
      'conversationId': conversationId,
    }, timeout: joinTimeout);
    if (response['ok'] == true) return true;
    // Recusada (ex.: conversa inexistente): deixa de ser desejada em vez de tentar para sempre.
    _rooms.remove(conversationId);
    return false;
  }

  Future<void> _loop(int run) async {
    var attempt = 0;
    var consecutiveAuthFailures = 0;

    bool alive() => _running && run == _runId;

    while (alive()) {
      final token = await _accessToken();
      if (!alive()) return;
      if (token == null) {
        // Sem token não há o que fazer: a sessão acabou.
        _running = false;
        _set(ChatConnectionStatus.stopped);
        return;
      }

      _set(ChatConnectionStatus.connecting, attempt: attempt);
      try {
        await _transport.connect(token: token);
        if (!alive()) {
          await _transport.disconnect();
          return;
        }
        await _rejoinRooms();
        attempt = 0;
        consecutiveAuthFailures = 0;
        _set(ChatConnectionStatus.connected);
        _resynced.add(null);

        await _untilDisconnected(run);
        if (!alive()) return;
        // Caiu: tenta reconectar já, sem esperar (o backoff só vale para tentativas que falham).
        continue;
      } on TransportAuthException {
        if (!alive()) return;
        final result = await _refresh(token);
        if (!alive()) return;
        if (result == TokenRefresh.sessionEnded) {
          _running = false;
          _set(ChatConnectionStatus.stopped);
          return;
        }
        // Renovou: tenta de novo na hora, mas só algumas vezes seguidas (o servidor pode estar
        // recusando por outro motivo e isso viraria um laço apertado).
        if (result == TokenRefresh.refreshed &&
            ++consecutiveAuthFailures <= 2) {
          continue;
        }
      } on TransportException {
        if (!alive()) return;
      }

      _set(ChatConnectionStatus.waiting, attempt: ++attempt);
      await _sleep(_backoff(attempt - 1), run);
    }
  }

  Future<void> _rejoinRooms() async {
    for (final room in _rooms.toList()) {
      // Uma falha de transporte aqui significa que a conexão não presta: sobe para o laço, que
      // derruba e reconecta. Uma recusa do servidor só remove a sala.
      try {
        await _join(room);
      } on TransportException {
        await _transport.disconnect();
        rethrow;
      }
    }
  }

  Future<void> _untilDisconnected(int run) {
    final done = Completer<void>();
    late StreamSubscription<bool> sub;
    sub = _transport.connectionChanges.listen((connected) {
      if (!connected && !done.isCompleted) done.complete();
    });
    // O que acontece entre o `connect` e o `listen` não pode ser perdido.
    if (!_transport.isConnected && !done.isCompleted) done.complete();
    _wake = () {
      if (!done.isCompleted) done.complete();
    };
    return done.future.whenComplete(() {
      sub.cancel();
      if (run == _runId) _wake = null;
    });
  }

  /// Espera [duration], mas acorda antes se alguém pedir `reconnectNow`/`stop`.
  Future<void> _sleep(Duration duration, int run) {
    final done = Completer<void>();
    final timer = Timer(duration, () {
      if (!done.isCompleted) done.complete();
    });
    _wake = () {
      timer.cancel();
      if (!done.isCompleted) done.complete();
    };
    return done.future.whenComplete(() {
      if (run == _runId) _wake = null;
    });
  }

  Future<void> dispose() async {
    await stop();
    await _states.close();
    await _resynced.close();
  }
}
