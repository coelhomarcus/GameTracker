import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/page_header.dart';
import '../../../core/design_system/primary_action.dart';
import '../application/feed_controller.dart';
import '../data/post_models.dart';
import '../../notifications/presentation/notifications_bell.dart';
import 'post_list.dart';

/// Comunidade: feed Geral (cronológico, sem algoritmo) e Seguindo.
class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final publish = PrimaryAction(
      heroTag: 'fab-community',
      icon: Icons.edit_outlined,
      label: 'Publicar',
      onPressed: () => context.push('/posts/new'),
    );
    return DefaultTabController(
      length: FeedScope.values.length,
      child: Scaffold(
        appBar: PageHeader(
          title: 'Comunidade',
          action: publish.headerButton(context),
          utilities: const [NotificationsBell()],
          bottom: TabBar(
            tabs: [
              for (final scope in FeedScope.values) Tab(text: scope.label),
            ],
          ),
        ),
        floatingActionButton: publish.fab(context),
        body: TabBarView(
          children: [
            for (final scope in FeedScope.values) FeedList(scope: scope),
          ],
        ),
      ),
    );
  }
}

class FeedList extends ConsumerWidget {
  const FeedList({super.key, required this.scope});

  final FeedScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PostList(
      provider: feedControllerProvider(scope),
      emptyBuilder: (context) {
        final following = scope == FeedScope.following;
        return EmptyView(
          icon: following ? Icons.group_outlined : Icons.forum_outlined,
          title: following
              ? 'Acompanhe quem joga com você'
              : 'Ainda não há publicações',
          message: following
              ? 'Quando quem você segue publicar ou jogar algo, aparece aqui.'
              : 'Seja a primeira pessoa a publicar.',
          action: following
              ? FilledButton(
                  onPressed: () => context.go('/explore?scope=people'),
                  child: const Text('Encontrar pessoas'),
                )
              : FilledButton.icon(
                  onPressed: () => context.push('/posts/new'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Publicar'),
                ),
        );
      },
    );
  }
}
