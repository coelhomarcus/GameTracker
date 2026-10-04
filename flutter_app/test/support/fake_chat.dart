import 'dart:async';

import 'package:gametracker/core/models/user_summary.dart';
import 'package:gametracker/core/realtime/chat_transport.dart';
import 'package:gametracker/features/chat/data/chat_models.dart';
import 'package:gametracker/features/chat/data/chat_repository.dart';

import 'fake_feed.dart';
import 'fake_transport.dart';

/// A conversa de teste, entre o usuário logado (`u1`, "ANA") e [beto].
const convId = 'conv-1';
const meId = 'u1';
const me = UserSummary(id: meId, username: 'ana', name: 'ANA');

ChatMessage serverMessage(
  String id, {
  String? cid,
  String text = 'oi',
  int minute = 0,
  bool mine = false,
  String conversation = convId,
}) => ChatMessage(
  id: id,
  clientMessageId: cid,
  conversationId: conversation,
  sender: mine ? me : beto,
  content: text,
  createdAt: DateTime.utc(2026, 6, 1, 12).add(Duration(minutes: minute)),
);

Map<String, dynamic> messageJson(ChatMessage m) => {
  'id': m.id,
  'clientMessageId': m.clientMessageId,
  'conversationId': m.conversationId,
  'senderId': m.sender.id,
  'content': m.content,
  'createdAt': m.createdAt.toIso8601String(),
  'sender': {
    'id': m.sender.id,
    'username': m.sender.username,
    'name': m.sender.name,
    'avatarUrl': m.sender.avatarUrl,
  },
};

ConversationSummary conversation({
  String id = convId,
  UserSummary other = beto,
  LastMessage? last,
  bool unread = false,
}) => ConversationSummary(
  id: id,
  otherUser: other,
  lastMessage: last,
  unread: unread,
);

/// REST do chat: lista de conversas e histórico paginado (mais recentes primeiro, cursor `cN`).
class FakeChatRepository implements ChatRepository {
  List<ConversationSummary> list = [conversation()];
  final history = <String, List<ChatMessage>>{};
  int pageSize = 2;

  Completer<void>? messagesGate;
  Object? messagesError;
  Object? conversationsError;
  Object? markReadError;
  int conversationsCalls = 0;
  final messageCalls = <(String, String?)>[];
  final markReadCalls = <String>[];
  final opened = <String>[];
  String openResult = convId;

  List<ChatMessage> _sorted(String conversationId) {
    final all = [...?history[conversationId]];
    all.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : b.id!.compareTo(a.id!);
    });
    return all;
  }

  @override
  Future<List<ConversationSummary>> conversations() async {
    conversationsCalls++;
    final error = conversationsError;
    if (error != null) throw error;
    return [...list];
  }

  @override
  Future<String> openWith(String userId) async {
    opened.add(userId);
    return openResult;
  }

  @override
  Future<MessagePage> messages(String conversationId, {String? cursor}) async {
    messageCalls.add((conversationId, cursor));
    await messagesGate?.future;
    final error = messagesError;
    if (error != null) throw error;
    final all = _sorted(conversationId);
    final start = cursor == null ? 0 : int.parse(cursor.substring(1));
    final end = (start + pageSize).clamp(0, all.length);
    return MessagePage(
      items: all.sublist(start, end),
      nextCursor: end < all.length ? 'c$end' : null,
    );
  }

  @override
  Future<void> markRead(String conversationId) async {
    markReadCalls.add(conversationId);
    final error = markReadError;
    if (error != null) throw error;
  }
}

/// O servidor do chat visto pelo transporte falso: grava mensagens de forma idempotente por
/// `clientMessageId`, entrega eventos e pode simular ACK perdido ou recusa.
class FakeChatServer {
  FakeChatServer(this.transport, this.repository) {
    transport.onRequest = _handle;
  }

  final FakeChatTransport transport;
  final FakeChatRepository repository;

  final _byClientId = <String, ChatMessage>{};
  int _seq = 0;
  int stored = 0;

  /// Entrega o evento `message:receive` ao remetente antes de responder o ACK.
  bool eventBeforeAck = false;

  /// Entrega o evento depois do ACK (o caso comum no backend: emit e depois ack).
  bool eventAfterAck = false;

  /// Quantas respostas de `message:send` serão perdidas (grava, mas o ACK nunca chega).
  int dropAcks = 0;

  /// Quantos envios o servidor "nem recebe" (timeout sem gravar).
  int ignoreSends = 0;

  /// Se definido, recusa o envio com este erro.
  String? rejectWith;

  /// Todas as chamadas a `message:send`.
  final sends = <Map<String, dynamic>>[];

  FutureOr<Map<String, dynamic>> _handle(
    String event,
    Map<String, dynamic> payload,
  ) {
    switch (event) {
      case 'conversation:join':
        return transport.rejectedRooms.contains(payload['conversationId'])
            ? {'error': 'Conversa não encontrada'}
            : {'ok': true};
      case 'presence:get':
        return {'online': transport.online};
      case 'message:send':
        return _send(payload);
      default:
        return {};
    }
  }

  Map<String, dynamic> _send(Map<String, dynamic> payload) {
    sends.add(payload);
    if (ignoreSends > 0) {
      ignoreSends--;
      throw const RequestTimeoutException();
    }
    final rejection = rejectWith;
    if (rejection != null) return {'error': rejection};

    final cid = payload['clientMessageId'] as String?;
    ChatMessage message;
    final existing = cid == null ? null : _byClientId[cid];
    final isNew = existing == null;
    if (existing != null) {
      message = existing;
    } else {
      message = ChatMessage(
        id: 'srv-${++_seq}',
        clientMessageId: cid,
        conversationId: payload['conversationId'] as String,
        sender: me,
        content: payload['content'] as String,
        createdAt: DateTime.utc(2026, 6, 1, 13).add(Duration(minutes: _seq)),
      );
      if (cid != null) _byClientId[cid] = message;
      stored++;
      (repository.history[message.conversationId] ??= []).add(message);
    }

    if (isNew && eventBeforeAck) {
      transport.emit(MessageReceived(messageJson(message)));
    }
    if (dropAcks > 0) {
      dropAcks--;
      throw const RequestTimeoutException();
    }
    if (isNew && eventAfterAck) {
      scheduleMicrotask(
        () => transport.emit(MessageReceived(messageJson(message))),
      );
    }
    return {'message': messageJson(message)};
  }

  /// Uma mensagem da outra pessoa chega ao vivo (e fica no histórico).
  ChatMessage incoming(String text, {int minute = 20, String? id}) {
    final message = ChatMessage(
      id: id ?? 'in-${++_seq}',
      conversationId: convId,
      sender: beto,
      content: text,
      createdAt: DateTime.utc(2026, 6, 1, 12).add(Duration(minutes: minute)),
    );
    (repository.history[convId] ??= []).add(message);
    transport.emit(MessageReceived(messageJson(message)));
    return message;
  }
}
