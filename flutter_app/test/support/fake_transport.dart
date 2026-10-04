import 'dart:async';

import 'package:gametracker/core/realtime/chat_transport.dart';

/// Resultado roteirizado de uma chamada a `connect`.
sealed class ConnectOutcome {
  const ConnectOutcome();
}

class ConnectOk extends ConnectOutcome {
  const ConnectOk();
}

class ConnectAuthError extends ConnectOutcome {
  const ConnectAuthError();
}

class ConnectFail extends ConnectOutcome {
  const ConnectFail();
}

/// Transporte falso: conexão, quedas, ACKs e eventos controlados pelo teste, sem rede.
class FakeChatTransport implements ChatTransport {
  /// Resultados consumidos em ordem; depois do último, repete `defaultOutcome`.
  final outcomes = <ConnectOutcome>[];
  ConnectOutcome defaultOutcome = const ConnectOk();

  /// Tokens usados em cada `connect`.
  final connectTokens = <String>[];

  /// Pedidos (evento, payload) enviados com `request`.
  final requests = <(String, Map<String, dynamic>)>[];

  /// Eventos sem ACK enviados com `send`.
  final sent = <(String, Map<String, dynamic>)>[];

  /// Responde a um pedido. Pode lançar `RequestTimeoutException` para simular ACK perdido.
  FutureOr<Map<String, dynamic>> Function(
    String event,
    Map<String, dynamic> payload,
  )?
  onRequest;

  /// Conversas que o servidor recusa na entrada.
  final rejectedRooms = <String>{};

  /// Presença que o servidor informa em `presence:get`.
  List<String> online = [];

  bool _connected = false;
  Completer<void>? connectGate;
  int disconnectCalls = 0;
  bool disposed = false;

  final _connection = StreamController<bool>.broadcast(sync: true);
  final _events = StreamController<ChatEvent>.broadcast(sync: true);

  @override
  bool get isConnected => _connected;

  @override
  Stream<bool> get connectionChanges => _connection.stream;

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Future<void> connect({required String token}) async {
    _connected = false;
    connectTokens.add(token);
    await connectGate?.future;
    final outcome = outcomes.isEmpty ? defaultOutcome : outcomes.removeAt(0);
    switch (outcome) {
      case ConnectAuthError():
        throw const TransportAuthException();
      case ConnectFail():
        throw const TransportException('recusada');
      case ConnectOk():
        _connected = true;
        _connection.add(true);
    }
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    if (_connected) {
      _connected = false;
      _connection.add(false);
    }
  }

  /// Simula a conexão caindo (rede, suspensão, servidor reiniciando).
  void drop() {
    if (!_connected) return;
    _connected = false;
    _connection.add(false);
  }

  /// Entrega um evento do servidor.
  void emit(ChatEvent event) => _events.add(event);

  @override
  Future<Map<String, dynamic>> request(
    String event,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!_connected) throw const NotConnectedException();
    requests.add((event, payload));
    final handler = onRequest;
    if (handler != null) return await handler(event, payload);
    switch (event) {
      case 'conversation:join':
        return rejectedRooms.contains(payload['conversationId'])
            ? {'error': 'Conversa não encontrada'}
            : {'ok': true};
      case 'presence:get':
        return {'online': online};
      default:
        return {};
    }
  }

  @override
  void send(String event, Map<String, dynamic> payload) {
    if (_connected) sent.add((event, payload));
  }

  @override
  void dispose() {
    disposed = true;
  }

  /// Conversas cuja entrada foi pedida, na ordem.
  List<String> get joins => [
    for (final r in requests)
      if (r.$1 == 'conversation:join') r.$2['conversationId'] as String,
  ];
}
