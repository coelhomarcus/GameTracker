import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

/// Rascunho do que está sendo escrito em cada conversa. Sobrevive a sair e voltar da tela (dentro
/// da sessão) e é descartado ao trocar de conta. Só vive em memória.
class ChatDrafts extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    ref.watch(currentUserIdProvider);
    return const {};
  }

  String textFor(String conversationId) => state[conversationId] ?? '';

  void set(String conversationId, String text) {
    final next = {...state};
    if (text.isEmpty) {
      next.remove(conversationId);
    } else {
      next[conversationId] = text;
    }
    state = next;
  }
}

final chatDraftsProvider = NotifierProvider<ChatDrafts, Map<String, String>>(
  ChatDrafts.new,
);
