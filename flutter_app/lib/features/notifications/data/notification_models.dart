import '../../../core/models/user_summary.dart';

enum NotificationType {
  like('like'),
  comment('comment'),
  follow('follow');

  const NotificationType(this.apiValue);
  final String apiValue;

  static NotificationType? fromApi(String value) {
    for (final t in NotificationType.values) {
      if (t.apiValue == value) return t;
    }
    return null;
  }
}

/// Filtros da central (docs/MIGRACAO_FLUTTER.md): Tudo, Interações (curtidas e comentários) e Seguidores.
enum NotificationFilter {
  all('Tudo'),
  interactions('Interações'),
  followers('Seguidores');

  const NotificationFilter(this.label);
  final String label;

  bool matches(NotificationType type) => switch (this) {
    NotificationFilter.all => true,
    NotificationFilter.interactions => type != NotificationType.follow,
    NotificationFilter.followers => type == NotificationType.follow,
  };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.actor,
    required this.read,
    required this.createdAt,
    this.postId,
  });

  /// `null` para tipos que este app não conhece (um backend mais novo): são ignorados em vez de quebrar a lista.
  static AppNotification? tryParse(Map<String, dynamic> json) {
    final type = NotificationType.fromApi(json['type'] as String? ?? '');
    final actor = json['actor'];
    if (type == null || actor is! Map<String, dynamic>) return null;
    return AppNotification(
      id: json['id'] as String,
      type: type,
      actor: UserSummary.fromJson(actor),
      postId: json['postId'] as String?,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final NotificationType type;
  final UserSummary actor;
  final String? postId;
  final bool read;
  final DateTime createdAt;

  AppNotification asRead() => AppNotification(
    id: id,
    type: type,
    actor: actor,
    postId: postId,
    read: true,
    createdAt: createdAt,
  );
}

/// `GET /notifications`: as últimas 50 e o contador de não lidas de TODAS (não só das 50).
class NotificationsData {
  const NotificationsData({required this.items, required this.unreadCount});

  factory NotificationsData.fromJson(Map<String, dynamic> json) =>
      NotificationsData(
        items: (json['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(AppNotification.tryParse)
            .whereType<AppNotification>()
            .toList(),
        unreadCount: json['unreadCount'] as int? ?? 0,
      );

  final List<AppNotification> items;
  final int unreadCount;

  /// O servidor devolve no máximo 50: com 50 itens, pode haver mais antigas que não aparecem.
  bool get maybeTruncated => items.length >= 50;

  NotificationsData allRead() => NotificationsData(
    items: [for (final n in items) n.asRead()],
    unreadCount: 0,
  );
}
