import 'dart:async';

import 'package:gametracker/core/models/user_summary.dart';
import 'package:gametracker/features/notifications/data/notification_models.dart';
import 'package:gametracker/features/notifications/data/notifications_repository.dart';

AppNotification fakeNotification(
  String id, {
  NotificationType type = NotificationType.like,
  UserSummary actor = const UserSummary(id: 'u-beto', username: 'beto'),
  String? postId = 'p1',
  bool read = false,
  DateTime? at,
}) => AppNotification(
  id: id,
  type: type,
  actor: actor,
  postId: type == NotificationType.follow ? null : postId,
  read: read,
  createdAt: at ?? DateTime.now().subtract(const Duration(minutes: 5)),
);

class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository([NotificationsData? data])
    : data = data ?? const NotificationsData(items: [], unreadCount: 0);

  NotificationsData data;
  Object? listError;
  Object? markError;
  Completer<void>? markGate;
  int listCalls = 0;
  int markCalls = 0;

  @override
  Future<NotificationsData> list() async {
    listCalls++;
    final error = listError;
    if (error != null) throw error;
    return data;
  }

  @override
  Future<void> markAllRead() async {
    markCalls++;
    await markGate?.future;
    final error = markError;
    if (error != null) throw error;
    data = data.allRead();
  }
}

NotificationsData notificationsOf(List<AppNotification> items, {int? unread}) =>
    NotificationsData(
      items: items,
      unreadCount: unread ?? items.where((n) => !n.read).length,
    );
