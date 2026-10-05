import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/design_system/tokens.dart';
import '../features/chat/application/conversations_controller.dart';
import '../features/feed/application/feed_controller.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Biblioteca', Icons.video_library_outlined, Icons.video_library),
  _Destination('Explorar', Icons.search, Icons.search),
  _Destination('Comunidade', Icons.forum_outlined, Icons.forum),
  _Destination('Mensagens', Icons.chat_bubble_outline, Icons.chat_bubble),
  _Destination('Perfil', Icons.person_outline, Icons.person),
];

/// Mesmos cinco destinos em qualquer largura: barra abaixo de 600, rail a partir daí.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _communityIndex = 2;
  static const _messagesIndex = 3;

  void _select(WidgetRef ref, int index) {
    // Ao entrar na Comunidade, revalida o feed se ele ficou velho ou foi marcado como
    // desatualizado (ex.: uma atividade criada pelo backend depois de salvar um registro).
    if (index == _communityIndex) {
      ref.read(feedRevalidatorProvider).revalidateIfStale();
    }
    // Não há evento por usuário no backend: ao entrar em Mensagens, a lista é revalidada.
    if (index == _messagesIndex &&
        ref.exists(conversationsControllerProvider)) {
      ref.read(conversationsControllerProvider.notifier).revalidateIfStale();
    }
    navigationShell.goBranch(
      index,
      // Tocar no destino já ativo volta à raiz dele.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// O ícone de Mensagens ganha um selo com as conversas não lidas.
  Widget _icon(_Destination d, {required bool selected, required int unread}) {
    final icon = Icon(selected ? d.selectedIcon : d.icon);
    if (d.label != 'Mensagens' || unread == 0) return icon;
    return Badge(label: Text('$unread'), child: icon);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final unread = ref.watch(unreadConversationsProvider);
    final label = unread == 0 ? 'Mensagens' : 'Mensagens, $unread não lidas';

    if (width < Breakpoints.medium) {
      // A conversa aberta ocupa a tela toda: sem a barra, o campo de mensagem fica logo acima
      // do teclado e a lista de mensagens ganha altura.
      final inConversation = GoRouterState.of(context).uri.path
          .startsWith('/messages/');
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: inConversation
            ? null
            : NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (i) => _select(ref, i),
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: _icon(d, selected: false, unread: unread),
                      selectedIcon: _icon(d, selected: true, unread: unread),
                      label: d.label,
                      tooltip: d.label == 'Mensagens' ? label : d.label,
                    ),
                ],
              ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (i) => _select(ref, i),
            extended: width >= Breakpoints.railExtended,
            labelType: width >= Breakpoints.railExtended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: _icon(d, selected: false, unread: unread),
                  selectedIcon: _icon(d, selected: true, unread: unread),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
