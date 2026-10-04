import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../application/notifications_controller.dart';

/// Sino da barra superior: abre a central e mostra quantas notificações não foram lidas.
class NotificationsBell extends ConsumerWidget {
  const NotificationsBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider);
    final label = unread == 0
        ? 'Notificações'
        : 'Notificações, $unread não lidas';
    return IconButton(
      tooltip: label,
      onPressed: () => context.push('/notifications'),
      icon: unread == 0
          ? const Icon(Icons.notifications_outlined)
          : Badge(
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.notifications),
            ),
    );
  }
}
