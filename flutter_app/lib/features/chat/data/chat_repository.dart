import 'package:dio/dio.dart';

import '../../../core/network/app_exception.dart';
import 'chat_models.dart';

abstract interface class ChatRepository {
  Future<List<ConversationSummary>> conversations();

  /// Cria ou reaproveita a conversa 1:1 com [userId] (o backend garante uma só por par).
  Future<String> openWith(String userId);

  /// Histórico paginado: mais recentes primeiro.
  Future<MessagePage> messages(String conversationId, {String? cursor});
  Future<void> markRead(String conversationId);
}

class RemoteChatRepository implements ChatRepository {
  RemoteChatRepository(this._dio);
  final Dio _dio;

  static const pageSize = 30;

  @override
  Future<List<ConversationSummary>> conversations() => guardApi(() async {
    final r = await _dio.get<List<dynamic>>('/conversations');
    return r.data!
        .cast<Map<String, dynamic>>()
        .map(ConversationSummary.fromJson)
        .toList();
  });

  @override
  Future<String> openWith(String userId) => guardApi(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/conversations',
      data: {'userId': userId},
    );
    return r.data!['id'] as String;
  });

  @override
  Future<MessagePage> messages(String conversationId, {String? cursor}) =>
      guardApi(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/conversations/$conversationId/messages',
          queryParameters: {'limit': pageSize, 'cursor': ?cursor},
        );
        return MessagePage.fromJson(r.data!);
      });

  @override
  Future<void> markRead(String conversationId) => guardApi(() async {
    await _dio.post<void>('/conversations/$conversationId/read');
  });
}
