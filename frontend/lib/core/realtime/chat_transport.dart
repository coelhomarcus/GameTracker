import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Eventos do servidor que o chat consome.
sealed class ChatEvent {
  const ChatEvent();
}

class MessageReceived extends ChatEvent {
  const MessageReceived(this.json);
  final Map<String, dynamic> json;
}

class TypingChanged extends ChatEvent {
  const TypingChanged({
    required this.conversationId,
    required this.userId,
    required this.typing,
  });
  final String conversationId;
  final String userId;
  final bool typing;
}

class PresenceChanged extends ChatEvent {
  const PresenceChanged({required this.userId, required this.online});
  final String userId;
  final bool online;
}

/// O servidor recusou o token no handshake (`unauthorized`): é preciso renovar a sessão.
class TransportAuthException implements Exception {
  const TransportAuthException();
}

/// Sem conexão (recusada, timeout, queda).
class TransportException implements Exception {
  const TransportException([this.message = 'Sem conexão com o servidor']);
  final String message;

  @override
  String toString() => 'TransportException: $message';
}

/// Não há socket conectado para enviar o pedido.
class NotConnectedException extends TransportException {
  const NotConnectedException() : super('Sem conexão em tempo real');
}

/// O servidor não respondeu o ACK a tempo: o pedido PODE ter sido processado.
class RequestTimeoutException extends TransportException {
  const RequestTimeoutException() : super('O servidor não respondeu a tempo');
}

/// Camada fina sobre o Socket.IO, para o resto do chat não depender do pacote (e ser testável).
/// Não reconecta sozinha: quem reconecta é o `ChatConnection`, porque cada tentativa precisa
/// de um access token válido e de reentrar nas salas.
abstract interface class ChatTransport {
  bool get isConnected;

  /// `true` ao conectar, `false` ao cair. Não emite o estado inicial.
  Stream<bool> get connectionChanges;
  Stream<ChatEvent> get events;

  /// Abre uma conexão NOVA autenticada por [token]. Falha com [TransportAuthException] se o
  /// servidor recusar o token e com [TransportException] nos demais casos.
  Future<void> connect({required String token});
  Future<void> disconnect();

  /// Evento com ACK. [NotConnectedException] sem conexão; [RequestTimeoutException] sem resposta.
  Future<Map<String, dynamic>> request(
    String event,
    Map<String, dynamic> payload, {
    Duration timeout,
  });

  /// Evento sem ACK (digitação).
  void send(String event, Map<String, dynamic> payload);

  void dispose();
}

class SocketIoTransport implements ChatTransport {
  SocketIoTransport({required this.url});

  final String url;
  io.Socket? _socket;
  final _connection = StreamController<bool>.broadcast();
  final _events = StreamController<ChatEvent>.broadcast();

  static const connectTimeout = Duration(seconds: 10);

  @override
  bool get isConnected => _socket?.connected ?? false;

  @override
  Stream<bool> get connectionChanges => _connection.stream;

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Future<void> connect({required String token}) async {
    await disconnect();
    final completer = Completer<void>();
    // `enableForceNew`: o pacote reaproveita sockets em cache por URL, o que manteria o token antigo.
    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .disableReconnection()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      if (!completer.isCompleted) {
        completer.complete();
      } else {
        _connection.add(true);
      }
    });
    socket.onConnectError((error) {
      if (completer.isCompleted) return;
      final message = error is Map ? error['message'] : error?.toString();
      completer.completeError(
        message == 'unauthorized'
            ? const TransportAuthException()
            : TransportException('$message'),
      );
    });
    socket.onDisconnect((_) {
      if (identical(_socket, socket)) _connection.add(false);
    });
    socket.on('message:receive', (data) {
      if (data is Map) {
        _events.add(MessageReceived(Map<String, dynamic>.from(data)));
      }
    });
    socket.on('typing:start', (data) => _typing(data, true));
    socket.on('typing:stop', (data) => _typing(data, false));
    socket.on('presence:online', (data) => _presence(data, true));
    socket.on('presence:offline', (data) => _presence(data, false));

    socket.connect();
    try {
      await completer.future.timeout(connectTimeout);
      _connection.add(true);
    } on TimeoutException {
      socket.dispose();
      if (identical(_socket, socket)) _socket = null;
      throw const TransportException('Tempo esgotado ao conectar');
    } catch (_) {
      socket.dispose();
      if (identical(_socket, socket)) _socket = null;
      rethrow;
    }
  }

  void _typing(Object? data, bool typing) {
    if (data is Map &&
        data['conversationId'] is String &&
        data['userId'] is String) {
      _events.add(
        TypingChanged(
          conversationId: data['conversationId'] as String,
          userId: data['userId'] as String,
          typing: typing,
        ),
      );
    }
  }

  void _presence(Object? data, bool online) {
    if (data is Map && data['userId'] is String) {
      _events.add(
        PresenceChanged(userId: data['userId'] as String, online: online),
      );
    }
  }

  /// Só para testes de integração: derruba o socket como uma queda de rede faria (o `disconnect`
  /// chega aos ouvintes), sem descartar o transporte.
  @visibleForTesting
  void simulateDrop() => _socket?.disconnect();

  @override
  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    socket?.dispose();
  }

  @override
  Future<Map<String, dynamic>> request(
    String event,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return Future.error(const NotConnectedException());
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(
      event,
      payload,
      ack: (data) {
        if (completer.isCompleted) return;
        completer.complete(
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
        );
      },
    );
    return completer.future.timeout(
      timeout,
      onTimeout: () => throw const RequestTimeoutException(),
    );
  }

  @override
  void send(String event, Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket != null && socket.connected) socket.emit(event, payload);
  }

  @override
  void dispose() {
    _socket?.dispose();
    _socket = null;
    _connection.close();
    _events.close();
  }
}
