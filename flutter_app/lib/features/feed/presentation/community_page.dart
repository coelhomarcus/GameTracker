import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/tokens.dart';
import '../application/feed_controller.dart';
import '../data/post_models.dart';
import 'post_tiles.dart';

/// Comunidade: feed Geral (cronológico, sem algoritmo) e Seguindo.
class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: FeedScope.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comunidade'),
          bottom: TabBar(
            tabs: [
              for (final scope in FeedScope.values) Tab(text: scope.label),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          // Tag própria: os FABs de todas as abas coexistem no IndexedStack.
          heroTag: 'fab-community',
          onPressed: () => context.push('/posts/new'),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Publicar'),
        ),
        body: TabBarView(
          children: [
            for (final scope in FeedScope.values) FeedList(scope: scope),
          ],
        ),
      ),
    );
  }
}

class FeedList extends ConsumerStatefulWidget {
  const FeedList({super.key, required this.scope});

  final FeedScope scope;

  @override
  ConsumerState<FeedList> createState() => _FeedListState();
}

class _FeedListState extends ConsumerState<FeedList>
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
    final state = ref.read(feedControllerProvider(widget.scope)).value;
    if (state?.loadMoreError != null) return;
    final position = _controller.position;
    // Também cobre a lista que ainda não enche a tela: não há rolagem para disparar o aviso.
    if (position.extentAfter < _prefetchExtent) {
      ref.read(feedControllerProvider(widget.scope).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(feedControllerProvider(widget.scope));
    final controller = ref.read(feedControllerProvider(widget.scope).notifier);

    return AsyncContent<FeedState>(
      value: feed,
      staleBanner: true,
      onRetry: () => ref.invalidate(feedControllerProvider(widget.scope)),
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
              ? _Empty(scope: widget.scope)
              : _Posts(
                  controller: _controller,
                  state: state,
                  scope: widget.scope,
                ),
        );
      },
    );
  }
}

class _Posts extends ConsumerWidget {
  const _Posts({
    required this.controller,
    required this.state,
    required this.scope,
  });

  final ScrollController controller;
  final FeedState state;
  final FeedScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: state.ids.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == state.ids.length) return _Footer(state: state, scope: scope);
        final id = state.ids[i];
        return PostTile(postId: id, onTap: () => context.push('/posts/$id'));
      },
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.state, required this.scope});

  final FeedState state;
  final FeedScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          children: [
            const Text('Não foi possível carregar mais posts.'),
            TextButton(
              onPressed: () =>
                  ref.read(feedControllerProvider(scope).notifier).loadMore(),
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

class _Empty extends StatelessWidget {
  const _Empty({required this.scope});

  final FeedScope scope;

  @override
  Widget build(BuildContext context) {
    final following = scope == FeedScope.following;
    // Dentro de um ListView para o pull-to-refresh continuar funcionando.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        EmptyView(
          icon: following ? Icons.group_outlined : Icons.forum_outlined,
          title: following ? 'Nada por aqui ainda' : 'Ainda não há posts',
          message: following
              ? 'Quando quem você segue publicar ou jogar algo, aparece aqui.'
              : 'Seja o primeiro a publicar.',
          action: following
              ? FilledButton(
                  onPressed: () => context.go('/explore'),
                  child: const Text('Encontrar pessoas'),
                )
              : FilledButton.icon(
                  onPressed: () => context.push('/posts/new'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Publicar'),
                ),
        ),
      ],
    );
  }
}
