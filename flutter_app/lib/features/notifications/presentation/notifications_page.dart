import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/dates/relative_time.dart';
import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../../../core/network/error_messages.dart';
import '../application/notifications_controller.dart';
import '../data/notification_models.dart';

/// Destino de uma notificação, montado só a partir de ids.
String? notificationRoute(AppNotification n) => switch (n.type) {
  NotificationType.follow => '/users/${n.actor.id}',
  NotificationType.like ||
  NotificationType.comment => n.postId == null ? null : '/posts/${n.postId}',
};

String notificationText(AppNotification n) => switch (n.type) {
  NotificationType.like => 'curtiu seu post',
  NotificationType.comment => 'comentou no seu post',
  NotificationType.follow => 'começou a seguir você',
};

/// Central de notificações: filtros, não lidas em destaque e "Marcar todas como lidas" explícito
/// (o backend só tem leitura global, então abrir um item não marca nada).
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  NotificationFilter _filter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    // Ao abrir, revalida se os dados estão velhos.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationsControllerProvider.notifier).revalidateIfStale();
      }
    });
  }

  Future<void> _markAll() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(notificationsControllerProvider.notifier).markAllRead();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsControllerProvider);
    final unread = notifications.value?.unreadCount ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/library'),
        ),
        title: const Text('Notificações'),
        actions: [
          if (unread > 0)
            IconButton(
              onPressed: _markAll,
              tooltip: 'Marcar todas como lidas',
              icon: const Icon(Icons.done_all),
            ),
        ],
      ),
      body: AsyncContent<NotificationsData>(
        value: notifications,
        staleBanner: true,
        onRetry: () => ref.invalidate(notificationsControllerProvider),
        data: (data) {
          final visible = data.items
              .where((n) => _filter.matches(n.type))
              .toList();
          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.lg,
                  vertical: Space.sm,
                ),
                child: Row(
                  spacing: Space.sm,
                  children: [
                    for (final f in NotificationFilter.values)
                      FilterChip(
                        label: Text(f.label),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    try {
                      await ref
                          .read(notificationsControllerProvider.notifier)
                          .refresh();
                    } catch (_) {
                      // O erro aparece no banner de dados desatualizados.
                    }
                  },
                  child: visible.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            _Empty(
                              filter: _filter,
                              hasAny: data.items.isNotEmpty,
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount:
                              visible.length + (data.maybeTruncated ? 1 : 0),
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            if (i == visible.length) {
                              return Padding(
                                padding: const EdgeInsets.all(Space.lg),
                                child: Center(
                                  child: Text(
                                    'Mostrando as 50 mais recentes.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                              );
                            }
                            return _Tile(notification: visible[i]);
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final actor = notification.actor;
    final route = notificationRoute(notification);
    final unread = !notification.read;

    return Semantics(
      label:
          '${unread ? 'Não lida. ' : ''}${actor.displayName} ${notificationText(notification)}, ${formatRelativeTime(notification.createdAt)}',
      button: route != null,
      excludeSemantics: true,
      child: ListTile(
        tileColor: unread
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : null,
        leading: UserAvatar(name: actor.displayName, url: actor.avatarUrl),
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: actor.displayName,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: ' ${notificationText(notification)}'),
            ],
          ),
        ),
        subtitle: Text(formatRelativeTime(notification.createdAt)),
        trailing: unread
            ? Icon(Icons.circle, size: 10, color: scheme.primary)
            : null,
        onTap: route == null ? null : () => context.push(route),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filter, required this.hasAny});

  final NotificationFilter filter;
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final (icon, title) = hasAny
        ? (Icons.filter_alt_off_outlined, 'Nada em "${filter.label}"')
        : (Icons.notifications_none, 'Sem notificações');
    return EmptyView(
      icon: icon,
      title: title,
      message: hasAny
          ? null
          : 'Curtidas, comentários e novos seguidores aparecem aqui.',
    );
  }
}
