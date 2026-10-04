import '../../../core/models/user_summary.dart';

/// Estado de entrega de uma mensagem enviada por mim.
enum MessageStatus {
  /// Na fila ou esperando o servidor confirmar.
  sending,

  /// O servidor confirmou (tem `id`).
  sent,

  /// O servidor não respondeu a tempo: PODE ter gravado. O reenvio é seguro (idempotente).
  uncertain,

  /// Não foi entregue. O texto continua na conversa, com "Tentar de novo" e "Descartar".
  failed,
}

class ChatMessage {
  const ChatMessage({
    required this.conversationId,
    required this.sender,
    required this.content,
    required this.createdAt,
    this.id,
    this.clientMessageId,
    this.status = MessageStatus.sent,
    this.attempts = 0,
    this.error,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    clientMessageId: json['clientMessageId'] as String?,
    conversationId: json['conversationId'] as String,
    sender: UserSummary.fromJson(json['sender'] as Map<String, dynamic>),
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  /// `null` enquanto o servidor não confirmou.
  final String? id;

  /// Gerado por quem envia. As mensagens antigas (cliente legado) não têm.
  final String? clientMessageId;
  final String conversationId;
  final UserSummary sender;
  final String content;

  /// Horário do servidor depois de confirmada; horário local enquanto pendente.
  final DateTime createdAt;
  final MessageStatus status;
  final int attempts;
  final String? error;

  bool get isConfirmed => id != null;

  /// Chave estável: não muda quando a mensagem pendente é confirmada (evita piscar na lista).
  String get key => clientMessageId ?? id!;

  ChatMessage copyWith({
    MessageStatus? status,
    int? attempts,
    Object? error = _keep,
  }) => ChatMessage(
    id: id,
    clientMessageId: clientMessageId,
    conversationId: conversationId,
    sender: sender,
    content: content,
    createdAt: createdAt,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    error: identical(error, _keep) ? this.error : error as String?,
  );

  static const _keep = Object();
}

/// Última mensagem de uma conversa na lista (versão enxuta).
class LastMessage {
  const LastMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.createdAt,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) => LastMessage(
    id: json['id'] as String,
    content: json['content'] as String,
    senderId: json['senderId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  factory LastMessage.fromMessage(ChatMessage m) => LastMessage(
    id: m.id ?? m.key,
    content: m.content,
    senderId: m.sender.id,
    createdAt: m.createdAt,
  );

  final String id;
  final String content;
  final String senderId;
  final DateTime createdAt;
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.unread,
    this.otherUser,
    this.lastMessage,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        id: json['id'] as String,
        otherUser: json['otherUser'] == null
            ? null
            : UserSummary.fromJson(json['otherUser'] as Map<String, dynamic>),
        lastMessage: json['lastMessage'] == null
            ? null
            : LastMessage.fromJson(json['lastMessage'] as Map<String, dynamic>),
        unread: json['unread'] as bool? ?? false,
      );

  final String id;
  final UserSummary? otherUser;
  final LastMessage? lastMessage;
  final bool unread;

  ConversationSummary copyWith({LastMessage? lastMessage, bool? unread}) =>
      ConversationSummary(
        id: id,
        otherUser: otherUser,
        lastMessage: lastMessage ?? this.lastMessage,
        unread: unread ?? this.unread,
      );
}

/// Página de histórico: mais recentes primeiro; `nextCursor` aponta para as mais antigas.
class MessagePage {
  const MessagePage({required this.items, required this.nextCursor});

  factory MessagePage.fromJson(Map<String, dynamic> json) => MessagePage(
    items: (json['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList(),
    nextCursor: json['nextCursor'] as String?,
  );

  final List<ChatMessage> items;
  final String? nextCursor;
}
