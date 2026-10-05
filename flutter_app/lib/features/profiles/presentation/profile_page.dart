import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/data/hours.dart';
import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/game_cover.dart';
import '../../../core/design_system/game_status.dart';
import '../../../core/design_system/status_chip.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../../../core/network/error_messages.dart';
import '../../../core/network/image_url.dart';
import '../../chat/presentation/start_conversation.dart';
import '../../feed/presentation/post_list.dart';
import '../../games/presentation/image_viewer.dart';
import '../../library/application/library_controller.dart';
import '../../library/application/library_view.dart';
import '../../library/application/library_prefs.dart';
import '../../library/data/game_entry.dart';
import '../application/follow_store.dart';
import '../application/profile_providers.dart';
import '../data/profile_models.dart';
import 'follow_button.dart';

/// Perfil próprio: destino real da navegação principal.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const SizedBox.shrink();
    return ProfileScreen(userId: userId, isMe: true);
  }
}

/// Perfil de outra pessoa, por id. O próprio usuário é redirecionado para `/me` pela rota.
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) =>
      ProfileScreen(userId: userId, isMe: false);
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.userId, required this.isMe});

  final String userId;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider(userId));
    return profile.when(
      skipLoadingOnRefresh: true,
      loading: () =>
          Scaffold(appBar: _bar(context, null), body: const LoadingView()),
      error: (e, _) => Scaffold(
        appBar: _bar(context, null),
        body: ErrorView(
          message: describeError(e),
          onRetry: () => ref.invalidate(profileProvider(userId)),
        ),
      ),
      data: (data) => _Loaded(profile: data, isMe: isMe),
    );
  }

  AppBar _bar(BuildContext context, UserProfile? profile) => AppBar(
    leading: isMe
        ? null
        : BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/community'),
          ),
    automaticallyImplyLeading: false,
    title: Text(isMe ? 'Perfil' : (profile?.displayName ?? 'Perfil')),
    actions: [
      if (isMe)
        IconButton(
          tooltip: 'Configurações',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
    ],
  );
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.profile, required this.isMe});

  final UserProfile profile;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: isMe
              ? null
              : BackButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/community'),
                ),
          automaticallyImplyLeading: false,
          title: Text(
            isMe ? 'Perfil' : profile.displayName,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (isMe)
              IconButton(
                tooltip: 'Configurações',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/settings'),
              ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: _Header(profile: profile, isMe: isMe),
            ),
          ],
          body: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Coleção'),
                  Tab(text: 'Atividades'),
                  Tab(text: 'Posts'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _CollectionTab(userId: profile.id, isMe: isMe),
                    PostList(
                      provider: userPostsControllerProvider((
                        userId: profile.id,
                        activities: true,
                      )),
                      emptyBuilder: (_) => const EmptyView(
                        icon: Icons.bolt_outlined,
                        title: 'Ainda não há atividades',
                      ),
                    ),
                    PostList(
                      provider: userPostsControllerProvider((
                        userId: profile.id,
                        activities: false,
                      )),
                      emptyBuilder: (_) => const EmptyView(
                        icon: Icons.forum_outlined,
                        title: 'Ainda não há posts',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.profile, required this.isMe});

  final UserProfile profile;
  final bool isMe;

  void _open(BuildContext context, String? url, String title) {
    if (url == null) return;
    ImageViewerPage.open(context, urls: [url], initialIndex: 0, title: title);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final follows = ref.watch(followStoreProvider);
    final followers = effectiveFollowerCount(
      follows,
      profile.id,
      serverValue: profile.followerCount,
    );
    final bannerUrl = ImageUrls.resolve(profile.bannerUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Semantics(
              button: bannerUrl != null,
              label: bannerUrl != null
                  ? 'Ampliar capa de ${profile.displayName}'
                  : 'Sem capa',
              child: InkWell(
                onTap: () => _open(
                  context,
                  profile.bannerUrl,
                  'Capa de ${profile.displayName}',
                ),
                child: AspectRatio(
                  aspectRatio: 3,
                  child: bannerUrl == null
                      ? ColoredBox(color: scheme.primaryContainer)
                      : Image.network(
                          bannerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              ColoredBox(color: scheme.primaryContainer),
                        ),
                ),
              ),
            ),
            Positioned(
              left: Space.lg,
              bottom: -40,
              child: Semantics(
                button: profile.avatarUrl != null,
                label: profile.avatarUrl != null
                    ? 'Ampliar foto de ${profile.displayName}'
                    : 'Sem foto',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _open(
                    context,
                    profile.avatarUrl,
                    'Foto de ${profile.displayName}',
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: UserAvatar(
                      name: profile.displayName,
                      url: profile.avatarUrl,
                      radius: 40,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: isMe
                ? OutlinedButton(
                    onPressed: () => context.push('/me/edit'),
                    child: const Text('Editar perfil'),
                  )
                : Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            startConversation(context, ref, profile.id),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Mensagem'),
                      ),
                      FollowButton(
                        userId: profile.id,
                        serverFollowing: profile.isFollowedByMe,
                        name: profile.displayName,
                      ),
                    ],
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.lg,
            Space.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.displayName, style: text.headlineSmall),
              Text('@${profile.username}', style: text.bodyMedium),
              if (profile.bioOrNull != null) ...[
                const SizedBox(height: Space.sm),
                Text(profile.bioOrNull!),
              ],
              const SizedBox(height: Space.md),
              // Rótulos, não links: não há tela de seguidores/seguindo (docs/MIGRACAO_FLUTTER.md).
              Wrap(
                spacing: Space.xl,
                runSpacing: Space.xs,
                children: [
                  _Counter(
                    value: followers,
                    label: followers == 1 ? 'seguidor' : 'seguidores',
                  ),
                  _Counter(value: profile.followingCount, label: 'seguindo'),
                  _Counter(
                    value: profile.entryCount,
                    label: profile.entryCount == 1 ? 'registro' : 'registros',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$value', style: text.titleSmall),
          TextSpan(text: ' $label', style: text.bodyMedium),
        ],
      ),
    );
  }
}

/// Coleção pública: favoritos, jogando agora, concluídos e todos os registros com filtro.
/// É somente leitura e nunca mostra as notas pessoais (o backend as devolve também a visitantes).
class _CollectionTab extends ConsumerStatefulWidget {
  const _CollectionTab({required this.userId, required this.isMe});

  final String userId;
  final bool isMe;

  @override
  ConsumerState<_CollectionTab> createState() => _CollectionTabState();
}

class _CollectionTabState extends ConsumerState<_CollectionTab>
    with AutomaticKeepAliveClientMixin {
  GameStatus? _filter;

  @override
  bool get wantKeepAlive => true;

  AsyncValue<List<GameEntry>> _entries() =>
      // O próprio usuário usa a coleção da Biblioteca (já carregada e sempre consistente).
      widget.isMe
      ? ref.watch(libraryProvider)
      : ref.watch(profileCollectionProvider(widget.userId));

  void _retry() => widget.isMe
      ? ref.invalidate(libraryProvider)
      : ref.invalidate(profileCollectionProvider(widget.userId));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final favorites = ref.watch(profileFavoritesProvider(widget.userId));
    return AsyncContent<List<GameEntry>>(
      value: _entries(),
      onRetry: _retry,
      data: (entries) {
        if (entries.isEmpty && (favorites.value?.isEmpty ?? true)) {
          return EmptyView(
            icon: Icons.video_library_outlined,
            title: widget.isMe ? 'Sua coleção está vazia' : 'Coleção vazia',
            message: widget.isMe
                ? 'Adicione jogos na Biblioteca.'
                : 'Esta pessoa ainda não registrou jogos.',
          );
        }
        final playing = entries
            .where((e) => e.status == GameStatus.playing)
            .toList();
        final completed = entries
            .where((e) => e.status == GameStatus.completed)
            .toList();
        final visible = applyLibraryView(
          entries,
          status: _filter,
          sort: LibrarySort.recent,
        );
        final counts = countByStatus(entries);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (favorites.value?.isNotEmpty ?? false)
                    _Shelf(
                      title: 'Favoritos',
                      children: [
                        for (final g in favorites.value!)
                          _ShelfGame(
                            name: g.name,
                            url: g.coverUrl,
                            igdbId: g.igdbId,
                          ),
                      ],
                    ),
                  if (playing.isNotEmpty)
                    _Shelf(
                      title: 'Jogando agora',
                      children: [
                        for (final e in playing)
                          _ShelfGame(
                            name: e.game.name,
                            url: e.game.coverUrl,
                            igdbId: e.game.igdbId,
                          ),
                      ],
                    ),
                  if (completed.isNotEmpty)
                    _Shelf(
                      title: 'Concluídos',
                      children: [
                        for (final e in completed)
                          _ShelfGame(
                            name: e.game.name,
                            url: e.game.coverUrl,
                            igdbId: e.game.igdbId,
                          ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.lg,
                      Space.lg,
                      Space.sm,
                    ),
                    child: Text(
                      'Todos os registros (${entries.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Row(
                      spacing: Space.sm,
                      children: [
                        FilterChip(
                          label: Text('Todos (${entries.length})'),
                          selected: _filter == null,
                          onSelected: (_) => setState(() => _filter = null),
                        ),
                        for (final s in GameStatus.values)
                          FilterChip(
                            avatar: Icon(s.icon, size: 18),
                            label: Text('${s.label} (${counts[s]})'),
                            selected: _filter == s,
                            onSelected: (_) => setState(
                              () => _filter = _filter == s ? null : s,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                ],
              ),
            ),
            if (visible.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(Space.xl),
                  child: Center(child: Text('Nenhum registro neste status.')),
                ),
              )
            else
              SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _EntryRow(entry: visible[i]),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
          ],
        );
      },
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.lg,
            Space.lg,
            Space.sm,
          ),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.md),
            itemBuilder: (_, i) => children[i],
          ),
        ),
      ],
    );
  }
}

class _ShelfGame extends StatelessWidget {
  const _ShelfGame({
    required this.name,
    required this.url,
    required this.igdbId,
  });

  final String name;
  final String? url;
  final int igdbId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Abrir $name',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/games/$igdbId'),
        child: SizedBox(
          width: 100,
          child: GameCover(name: name, url: url),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final GameEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(
        width: 48,
        child: GameCover(
          name: entry.game.name,
          url: entry.game.coverUrl,
          radius: 8,
        ),
      ),
      title: Text(
        entry.game.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: Space.xs),
        child: Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusChip(entry.status),
            Text(entry.platform),
            if (entry.hoursPlayed != null)
              Text('${formatHours(entry.hoursPlayed!)} h'),
            if (entry.rating != null) Text('Nota ${entry.rating}/10'),
          ],
        ),
      ),
      onTap: () => context.push('/games/${entry.game.igdbId}'),
    );
  }
}
