import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../library/application/library_groups.dart';
import '../data/chat_models.dart';

/// Busca e filtro "Não lidas" da lista de conversas. Só em memória: sobrevivem à troca de aba e a
/// abrir uma conversa, e são descartados ao sair da conta.
class ConversationFilter {
  const ConversationFilter({this.query = '', this.unreadOnly = false});

  final String query;
  final bool unreadOnly;

  bool get isActive => query.trim().isNotEmpty || unreadOnly;

  ConversationFilter copyWith({String? query, bool? unreadOnly}) =>
      ConversationFilter(
        query: query ?? this.query,
        unreadOnly: unreadOnly ?? this.unreadOnly,
      );
}

class ConversationFilterController extends Notifier<ConversationFilter> {
  @override
  ConversationFilter build() {
    ref.watch(currentUserIdProvider);
    return const ConversationFilter();
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  void setUnreadOnly(bool value) => state = state.copyWith(unreadOnly: value);

  void clear() => state = const ConversationFilter();
}

final conversationFilterProvider =
    NotifierProvider<ConversationFilterController, ConversationFilter>(
      ConversationFilterController.new,
    );

/// Conversas que passam pela busca (nome ou username, sem caixa nem acentos) e, com [unreadOnly],
/// só as não lidas. A ordem é a que a lista já tem.
List<ConversationSummary> filterConversations(
  List<ConversationSummary> all,
  ConversationFilter filter,
) {
  final query = foldText(filter.query);
  return [
    for (final c in all)
      if ((!filter.unreadOnly || c.unread) && _matches(c, query)) c,
  ];
}

bool _matches(ConversationSummary c, String query) {
  if (query.isEmpty) return true;
  final other = c.otherUser;
  if (other == null) return false;
  return foldText(other.displayName).contains(query) ||
      foldText(other.username).contains(query);
}
