import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/primary_action.dart';
import '../application/feed_controller.dart';
import 'post_tiles.dart';

/// Lista de posts paginada por cursor (feed, atividades e posts de um perfil). Pede a próxima
/// página perto do fim, nunca repete sozinha depois de uma falha e mantém a rolagem entre abas.
class PostList extends ConsumerStatefulWidget {
  const PostList({
    super.key,
    required this.provider,
    required this.emptyBuilder,
  });

  final AsyncNotifierProvider<PagedPostsController, FeedState> provider;

  /// Conteúdo quando não há posts (dentro de um ListView, para o pull-to-refresh funcionar).
  final WidgetBuilder emptyBuilder;

  @override
  ConsumerState<PostList> createState() => _PostListState();
}

class _PostListState extends ConsumerState<PostList>
    with AutomaticKeepAliveClientMixin {
  final _controller = ScrollController();

  /// Distância do fim (em px) a partir da qual a próxima página é pedida.
  static const _prefetchExtent = 400.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_controller.hasClients) return;
    // Depois de uma falha, só o botão "Tentar de novo" repete: sem isso, cada reconstrução
    // da lista dispararia outra tentativa e o app ficaria martelando um servidor fora do ar.
    final state = ref.read(widget.provider).value;
    if (state?.loadMoreError != null) return;
    // Também cobre a lista que ainda não enche a tela: não há rolagem para disparar o aviso.
    if (_controller.position.extentAfter < _prefetchExtent) {
      ref.read(widget.provider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final posts = ref.watch(widget.provider);
    final controller = ref.read(widget.provider.notifier);

    return AsyncContent<FeedState>(
      value: posts,
      staleBanner: true,
      onRetry: () => ref.invalidate(widget.provider),
      data: (state) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeLoadMore();
        });
        return RefreshIndicator(
          onRefresh: () async {
            try {
              await controller.refresh();
            } catch (_) {
              // O erro aparece no banner de dados desatualizados.
            }
          },
          child: state.ids.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    widget.emptyBuilder(context),
                  ],
                )
              : ListView.separated(
                  controller: _controller,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(
                    bottom: PrimaryAction.fabClearance,
                  ),
                  itemCount: state.ids.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    if (i == state.ids.length) {
                      return PostListFooter(
                        state: state,
                        provider: widget.provider,
                      );
                    }
                    final id = state.ids[i];
                    return PostTile(
                      postId: id,
                      onTap: () => context.push('/posts/$id'),
                    );
                  },
                ),
        );
      },
    );
  }
}

/// Rodapé de uma lista paginada: carregando mais, erro com "Tentar de novo" ou fim.
class PostListFooter extends ConsumerWidget {
  const PostListFooter({
    super.key,
    required this.state,
    required this.provider,
  });

  final FeedState state;
  final AsyncNotifierProvider<PagedPostsController, FeedState> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          children: [
            const Text('Não foi possível carregar mais posts.'),
            TextButton(
              onPressed: () => ref.read(provider.notifier).loadMore(),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(Space.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Center(
          child: Text(
            'Você chegou ao fim.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return const SizedBox(height: Space.xl);
  }
}
