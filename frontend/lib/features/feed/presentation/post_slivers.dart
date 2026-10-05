import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/network/error_messages.dart';
import '../application/feed_controller.dart';
import 'post_list.dart';
import 'post_tiles.dart';

typedef PostsProvider = AsyncNotifierProvider<PagedPostsController, FeedState>;

/// Distância do fim, em px, a partir da qual a próxima página é pedida.
const _prefetchExtent = 400.0;

/// Uma lista de posts paginada como slivers, para páginas de rolagem única (jogo, perfil): sem
/// rolagem aninhada. Cobre carregando, erro com nova tentativa, vazio, os posts e o rodapé de
/// "carregar mais". Quem usa liga [loadMorePostsOnScroll] à rolagem da página.
List<Widget> postSlivers({
  required WidgetRef ref,
  required PostsProvider provider,
  required EdgeInsets insets,
  required Widget empty,
}) {
  final posts = ref.watch(provider);
  final bottom = insets.copyWith(bottom: Space.xxl);
  if (!posts.hasValue) {
    return [
      SliverPadding(
        padding: bottom,
        sliver: SliverToBoxAdapter(
          child: posts.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(Space.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              : ErrorView(
                  message: describeError(posts.error!),
                  onRetry: () => ref.invalidate(provider),
                ),
        ),
      ),
    ];
  }
  final state = posts.requireValue;
  if (state.ids.isEmpty) {
    return [
      SliverPadding(
        padding: bottom,
        sliver: SliverToBoxAdapter(child: empty),
      ),
    ];
  }
  return [
    SliverPadding(
      padding: EdgeInsets.fromLTRB(insets.left, 0, insets.right, Space.xxl),
      sliver: SliverList.separated(
        itemCount: state.ids.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == state.ids.length) {
            return PostListFooter(state: state, provider: provider);
          }
          final id = state.ids[i];
          return PostTile(postId: id, onTap: () => context.push('/posts/$id'));
        },
      ),
    ),
  ];
}

/// Pede a próxima página perto do fim da rolagem. Depois de uma falha, só o botão do rodapé
/// repete. Devolve `false` para a notificação seguir adiante.
bool loadMorePostsOnScroll(
  Notification notification,
  WidgetRef ref,
  PostsProvider provider, {
  required bool Function() isMounted,
}) {
  final ScrollMetrics? metrics = switch (notification) {
    ScrollNotification(:final metrics) => metrics,
    ScrollMetricsNotification(:final metrics) => metrics,
    _ => null,
  };
  if (metrics == null || metrics.axis != Axis.vertical) return false;
  if (metrics.extentAfter < _prefetchExtent) {
    // Fora do quadro atual: as notificações podem chegar durante o layout.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) return;
      if (ref.read(provider).value?.loadMoreError != null) return;
      ref.read(provider.notifier).loadMore();
    });
  }
  return false;
}
