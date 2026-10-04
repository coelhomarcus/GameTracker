final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Destino de um push. A rota é montada só a partir de ids validados; o payload nunca traz
/// caminho nem URL. `null` quando o push não é para a conta atual, é de um tipo desconhecido
/// (backend mais novo) ou tem ids inválidos: nesses casos nada é aberto.
String? resolvePushRoute(Map<String, String> data, {required String? userId}) {
  if (userId == null || data['recipientId'] != userId) return null;

  String? id(String key) {
    final value = data[key];
    return value != null && _uuid.hasMatch(value) ? value : null;
  }

  return switch (data['type']) {
    'like' || 'comment' => switch (id('postId')) {
      final postId? => '/posts/$postId',
      _ => '/notifications',
    },
    'follow' => switch (id('actorId')) {
      final actorId? => '/users/$actorId',
      _ => '/notifications',
    },
    'message' => switch (id('conversationId')) {
      final conversationId? => '/messages/$conversationId',
      _ => null,
    },
    _ => null,
  };
}

/// Se o push é uma notificação da central (curtida, comentário, seguidor).
bool isInboxPush(Map<String, String> data) => switch (data['type']) {
  'like' || 'comment' || 'follow' => true,
  _ => false,
};
