import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/game_card.dart';
import '../../../core/design_system/game_status.dart';
import '../../../core/design_system/page_container.dart';
import '../../../core/design_system/pinned_tab_bar.dart';
import '../../../core/design_system/section_header.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../../../core/network/error_messages.dart';
import '../../../core/network/image_url.dart';
import '../../../core/navigation/back_navigation.dart';
import '../../chat/presentation/start_conversation.dart';
import '../../feed/presentation/post_slivers.dart';
import '../../games/data/game_models.dart';
import '../../games/presentation/image_viewer.dart';
import '../../library/application/library_controller.dart';
import '../../library/application/library_groups.dart';
import '../../library/data/game_entry.dart';
import '../../notifications/presentation/notifications_bell.dart';
import '../application/follow_store.dart';
import '../application/profile_providers.dart';
import '../data/profile_models.dart';
import 'follow_button.dart';

/// A partir deste espaço útil o perfil usa duas colunas: identidade e destaques à esquerda, abas
/// e conteúdo à direita.
const _twoColumnMinWidth = 1000.0;
const _identityColumnWidth = 280.0;
const _highlightsLimit = 6;

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
        body: isNotFound(e)
            ? UnavailableView(
                what: 'perfil',
                onBack: () => goBackOr(context, '/community'),
              )
            : ErrorView(
                message: describeError(e),
                onRetry: () => ref.invalidate(profileProvider(userId)),
              ),
      ),
      data: (data) => _Loaded(profile: data, isMe: isMe),
    );
  }

  AppBar _bar(BuildContext context, UserProfile? profile) => AppBar(
    leading: isMe ? null : const FallbackBackButton(fallback: '/community'),
    automaticallyImplyLeading: false,
    title: Text(
      isMe ? 'Perfil' : (profile?.displayName ?? 'Perfil'),
      overflow: TextOverflow.ellipsis,
    ),
    actions: [
      if (isMe) ...[
        const NotificationsBell(),
        IconButton(
          tooltip: 'Configurações',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
      ],
    ],
  );
}

class _Loaded extends ConsumerStatefulWidget {
  const _Loaded({required this.profile, required this.isMe});

  final UserProfile profile;
  final bool isMe;

  @override
  ConsumerState<_Loaded> createState() => _LoadedState();
}

class _LoadedState extends ConsumerState<_Loaded>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  /// Filtro de status da aba Jogos e a seção de favoritos expandida: só desta tela.
  GameStatus? _status;
  bool _favoritesExpanded = false;

  static const _gamesTab = 0;

  PostsProvider? get _postsProvider => switch (_tabs.index) {
    1 => userPostsControllerProvider((
      userId: widget.profile.id,
      activities: true,
    )),
    2 => userPostsControllerProvider((
      userId: widget.profile.id,
      activities: false,
    )),
    _ => null,
  };

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  AsyncValue<List<GameEntry>> _collection() =>
      // O próprio usuário usa a coleção da Biblioteca (já carregada e sempre consistente).
      widget.isMe
      ? ref.watch(libraryProvider)
      : ref.watch(profileCollectionProvider(widget.profile.id));

  void _retryCollection() => widget.isMe
      ? ref.invalidate(libraryProvider)
      : ref.invalidate(profileCollectionProvider(widget.profile.id));

  Future<void> _refresh() async {
    final id = widget.profile.id;
    ref.invalidate(profileFavoritesProvider(id));
    final provider = _postsProvider;
    try {
      if (provider != null) {
        await ref.read(provider.notifier).refresh();
      } else if (widget.isMe) {
        await ref.read(libraryProvider.notifier).refresh();
      } else {
        ref.invalidate(profileCollectionProvider(id));
        await ref.read(profileCollectionProvider(id).future);
      }
    } catch (_) {
      // O erro aparece na própria seção.
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final collection = _collection();
    final favorites = ref.watch(profileFavoritesProvider(profile.id));
    final overview = collection.hasValue
        ? buildLibraryOverview(
            collection.requireValue,
            filter: LibraryFilter(status: _status),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: widget.isMe
            ? null
            : const FallbackBackButton(fallback: '/community'),
        automaticallyImplyLeading: false,
        title: Text(
          widget.isMe ? 'Perfil' : profile.displayName,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.isMe) ...[
            const NotificationsBell(),
            IconButton(
              tooltip: 'Configurações',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ],
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final twoColumns = box.maxWidth >= _twoColumnMinWidth;
          final identity = _Identity(
            profile: profile,
            isMe: widget.isMe,
            wide: twoColumns,
            games: overview?.summary.games,
            records: widget.isMe && collection.hasValue
                ? collection.requireValue.length
                : profile.entryCount,
          );
          final highlights = _Highlights(
            favorites: favorites.value ?? const [],
            playing: overview?.shelf ?? const [],
            expanded: _favoritesExpanded,
            onToggleExpanded: () =>
                setState(() => _favoritesExpanded = !_favoritesExpanded),
            coverSize: twoColumns ? 80 : 96,
          );
          final tabs = SliverPersistentHeader(
            pinned: true,
            delegate: PinnedTabBarDelegate(
              TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: 'Jogos'),
                  Tab(text: 'Atividade'),
                  Tab(text: 'Posts'),
                ],
              ),
              Theme.of(context).colorScheme.surface,
            ),
          );

          // No celular os destaques abrem a aba Jogos (são sobre jogos) e a barra de abas fica
          // logo depois da identidade, à vista na primeira tela. Em duas colunas ficam à esquerda.
          final Widget? belowTabs = twoColumns ? null : highlights;

          Widget scroll(List<Widget> leading, EdgeInsets insets) =>
              NotificationListener<Notification>(
                onNotification: (n) {
                  final provider = _postsProvider;
                  return provider == null
                      ? false
                      : loadMorePostsOnScroll(
                          n,
                          ref,
                          provider,
                          isMounted: () => mounted,
                        );
                },
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListenableBuilder(
                    listenable: _tabs,
                    builder: (context, _) => CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        ...leading,
                        tabs,
                        ..._content(collection, overview, insets, belowTabs),
                      ],
                    ),
                  ),
                ),
              );

          if (twoColumns) {
            // Duas colunas lado a lado, cada uma com a sua rolagem: não há rolagem aninhada.
            return PageContainer(
              width: PageWidth.wide,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.xl,
                children: [
                  SizedBox(
                    width: _identityColumnWidth,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: Space.xxl),
                      child: Column(children: [identity, highlights]),
                    ),
                  ),
                  Expanded(child: scroll(const [], EdgeInsets.zero)),
                ],
              ),
            );
          }
          final insets = PageContainer.insetsFor(
            box.maxWidth,
            PageWidth.reading,
          );
          return scroll([
            SliverToBoxAdapter(child: identity),
          ], insets.copyWith(top: Space.lg));
        },
      ),
    );
  }

  List<Widget> _content(
    AsyncValue<List<GameEntry>> collection,
    LibraryOverview? overview,
    EdgeInsets insets,
    Widget? highlights,
  ) {
    final id = widget.profile.id;
    final padded = insets.copyWith(top: Space.lg);
    switch (_tabs.index) {
      case _gamesTab:
        return [
          if (highlights != null)
            SliverPadding(
              padding: padded,
              sliver: SliverToBoxAdapter(child: highlights),
            ),
          SliverPadding(
            padding: padded.copyWith(top: highlights == null ? Space.lg : 0),
            sliver: SliverToBoxAdapter(
              child: _GamesHeader(
                overview: overview,
                status: _status,
                onStatus: (s) => setState(() => _status = s),
              ),
            ),
          ),
          ..._gamesSlivers(collection, overview, insets),
        ];
      case 1:
        return postSlivers(
          ref: ref,
          provider: userPostsControllerProvider((userId: id, activities: true)),
          insets: padded,
          empty: const EmptyView(
            icon: Icons.bolt_outlined,
            title: 'Ainda não há atividades',
          ),
        );
      default:
        return postSlivers(
          ref: ref,
          provider: userPostsControllerProvider((
            userId: id,
            activities: false,
          )),
          insets: padded,
          empty: const EmptyView(
            icon: Icons.forum_outlined,
            title: 'Ainda não há posts',
          ),
        );
    }
  }

  /// A grade de jogos (agrupados, como na Biblioteca): carregando, erro, vazio e resultado.
  List<Widget> _gamesSlivers(
    AsyncValue<List<GameEntry>> collection,
    LibraryOverview? overview,
    EdgeInsets insets,
  ) {
    final bottom = insets.copyWith(top: Space.md, bottom: Space.xxl);
    if (overview == null) {
      return [
        SliverPadding(
          padding: bottom,
          sliver: SliverToBoxAdapter(
            child: collection.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(Space.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ErrorView(
                    message: describeError(collection.error!),
                    onRetry: _retryCollection,
                  ),
          ),
        ),
      ];
    }
    if (overview.summary.games == 0) {
      return [
        SliverPadding(
          padding: bottom,
          sliver: SliverToBoxAdapter(
            child: EmptyView(
              icon: Icons.video_library_outlined,
              title: widget.isMe ? 'Sua coleção está vazia' : 'Coleção vazia',
              message: widget.isMe
                  ? 'Adicione jogos na Biblioteca.'
                  : 'Esta pessoa ainda não registrou jogos.',
            ),
          ),
        ),
      ];
    }
    if (overview.groups.isEmpty) {
      return [
        SliverPadding(
          padding: bottom,
          sliver: const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(Space.xl),
              child: Center(child: Text('Nenhum jogo neste status.')),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: bottom,
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) => SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: GameCard.columnsFor(constraints.crossAxisExtent),
              mainAxisSpacing: Space.md,
              crossAxisSpacing: Space.md,
              childAspectRatio: 3 / 4,
            ),
            itemCount: overview.groups.length,
            itemBuilder: (context, i) => _GameTile(group: overview.groups[i]),
          ),
        ),
      ),
    ];
  }
}

/// Banner 3:1 com o avatar sobreposto na borda inferior esquerda; nome, handle e bio ficam fora
/// da imagem, sobre a superfície. Em duas colunas é um cartão estreito, com as ações embaixo.
class _Identity extends ConsumerWidget {
  const _Identity({
    required this.profile,
    required this.isMe,
    required this.wide,
    required this.games,
    required this.records,
  });

  final UserProfile profile;
  final bool isMe;
  final bool wide;

  /// Jogos únicos da coleção; `null` enquanto carrega ou se a coleção falhou (nunca zero).
  final int? games;
  final int records;

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
    // Diâmetro total (com a borda de 3): 88 no telefone e 112 em conteúdo largo.
    final avatarSize = wide ? 112.0 : 88.0;
    final inset = wide ? 0.0 : Space.lg;

    final actions = isMe
        ? [
            OutlinedButton(
              onPressed: () => context.push('/me/edit'),
              child: const Text('Editar perfil'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/library'),
              icon: const Icon(Icons.video_library_outlined, size: 18),
              label: const Text('Gerenciar biblioteca'),
            ),
          ]
        : [
            OutlinedButton.icon(
              onPressed: () => startConversation(context, ref, profile.id),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Mensagem'),
            ),
            FollowButton(
              userId: profile.id,
              serverFollowing: profile.isFollowedByMe,
              name: profile.displayName,
            ),
          ];

    final banner = Semantics(
      button: bannerUrl != null,
      label: bannerUrl != null
          ? 'Ampliar capa de ${profile.displayName}'
          : 'Sem capa',
      child: InkWell(
        onTap: () =>
            _open(context, profile.bannerUrl, 'Capa de ${profile.displayName}'),
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
    );
    final avatar = Semantics(
      button: profile.avatarUrl != null,
      label: profile.avatarUrl != null
          ? 'Ampliar foto de ${profile.displayName}'
          : 'Sem foto',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () =>
            _open(context, profile.avatarUrl, 'Foto de ${profile.displayName}'),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
          ),
          child: UserAvatar(
            name: profile.displayName,
            url: profile.avatarUrl,
            radius: (avatarSize - 6) / 2,
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // O avatar fica na borda inferior do banner, metade em cima e metade embaixo. A zona de
        // baixo faz parte do Stack: fora dos limites dele a metade inferior do avatar não
        // receberia toque. No telefone as ações ocupam essa zona, à direita.
        LayoutBuilder(
          builder: (context, box) {
            final bannerHeight = box.maxWidth / 3;
            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    banner,
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: avatarSize / 2 + Space.sm,
                      ),
                      child: wide
                          ? null
                          : Padding(
                              // Começa depois do avatar: com texto grande os botões quebram de
                              // linha em vez de passar por cima dele.
                              padding: EdgeInsets.fromLTRB(
                                inset + avatarSize + Space.sm,
                                Space.sm,
                                inset,
                                0,
                              ),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: Space.sm,
                                  runSpacing: Space.sm,
                                  alignment: WrapAlignment.end,
                                  children: actions,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
                Positioned(
                  left: wide ? Space.md : inset,
                  top: bannerHeight - avatarSize / 2,
                  child: avatar,
                ),
              ],
            );
          },
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            wide ? Space.xs : inset,
            Space.sm,
            wide ? Space.xs : inset,
            Space.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                style: text.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text('@${profile.username}', style: text.bodyMedium),
              if (profile.bioOrNull != null) ...[
                const SizedBox(height: Space.sm),
                Text(profile.bioOrNull!, style: text.bodyLarge),
              ] else if (isMe) ...[
                const SizedBox(height: Space.xs),
                TextButton.icon(
                  onPressed: () => context.push('/me/edit'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Conte um pouco sobre você'),
                ),
              ],
              const SizedBox(height: Space.md),
              // Rótulos, não links: não há tela de seguidores/seguindo (docs/MIGRACAO_FLUTTER.md).
              Wrap(
                spacing: Space.xl,
                runSpacing: Space.xs,
                children: [
                  if (games != null)
                    _Counter(
                      value: games!,
                      label: games == 1 ? 'jogo' : 'jogos',
                    ),
                  _Counter(
                    value: records,
                    label: records == 1 ? 'registro' : 'registros',
                  ),
                  _Counter(
                    value: followers,
                    label: followers == 1 ? 'seguidor' : 'seguidores',
                  ),
                  _Counter(value: profile.followingCount, label: 'seguindo'),
                ],
              ),
              if (wide) ...[
                const SizedBox(height: Space.md),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: actions,
                ),
              ],
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

/// Favoritos (até 6; "Ver todos" expande aqui mesmo) e Jogando agora (até 6, um por jogo). A ordem
/// é a dos dados: a API não guarda reordenação, então a tela não oferece arrastar.
class _Highlights extends StatelessWidget {
  const _Highlights({
    required this.favorites,
    required this.playing,
    required this.expanded,
    required this.onToggleExpanded,
    required this.coverSize,
  });

  final List<Game> favorites;
  final List<LibraryGroup> playing;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final double coverSize;

  @override
  Widget build(BuildContext context) {
    final shownFavorites = expanded
        ? favorites
        : favorites.take(_highlightsLimit).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (favorites.isNotEmpty) ...[
            SectionHeader(
              title: 'Favoritos',
              actionLabel: favorites.length > _highlightsLimit
                  ? (expanded ? 'Ver menos' : 'Ver todos')
                  : null,
              onAction: favorites.length > _highlightsLimit
                  ? onToggleExpanded
                  : null,
            ),
            _CoverWrap(
              size: coverSize,
              covers: [
                for (final g in shownFavorites)
                  (title: g.name, url: g.coverUrl, igdbId: g.igdbId),
              ],
            ),
            const SizedBox(height: Space.lg),
          ],
          if (playing.isNotEmpty) ...[
            const SectionHeader(title: 'Jogando agora'),
            _CoverWrap(
              size: coverSize,
              covers: [
                for (final g in playing)
                  (
                    title: g.game.name,
                    url: g.game.coverUrl,
                    igdbId: g.game.igdbId,
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
          ],
        ],
      ),
    );
  }
}

typedef _Cover = ({String title, String? url, int igdbId});

class _CoverWrap extends StatelessWidget {
  const _CoverWrap({required this.size, required this.covers});

  final double size;
  final List<_Cover> covers;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final c in covers)
          SizedBox(
            width: size,
            child: GameCard(
              title: c.title,
              coverUrl: c.url,
              showDetails: false,
              onTap: () => context.push('/games/${c.igdbId}'),
            ),
          ),
      ],
    );
  }
}

/// Filtro de status da aba Jogos, com contagem de jogos distintos.
class _GamesHeader extends StatelessWidget {
  const _GamesHeader({
    required this.overview,
    required this.status,
    required this.onStatus,
  });

  final LibraryOverview? overview;
  final GameStatus? status;
  final ValueChanged<GameStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    final overview = this.overview;
    // Sem a coleção (carregando ou com erro) não há contagem para mostrar: nada de zeros.
    if (overview == null || overview.summary.games == 0) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.xs,
      children: [
        FilterChip(
          label: Text('Todos (${overview.totalGames})'),
          selected: status == null,
          onSelected: (_) => onStatus(null),
        ),
        for (final s in GameStatus.values)
          FilterChip(
            avatar: Icon(s.icon, size: 18),
            label: Text('${s.label} (${overview.statusCounts[s]})'),
            selected: status == s,
            onSelected: (_) => onStatus(status == s ? null : s),
          ),
      ],
    );
  }
}

/// Capa na grade de jogos do perfil: abre o jogo; sem menu (o perfil é só leitura) e sem
/// título, plataforma, horas ou nota fixos. Vários registros do mesmo jogo viram um selo.
class _GameTile extends StatelessWidget {
  const _GameTile({required this.group});

  final LibraryGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = [if (group.mixedStatus) 'Vários status', ?group.recordsLabel];
    return GameCard(
      title: group.game.name,
      coverUrl: group.game.coverUrl,
      status: group.singleStatus,
      caption: parts.isEmpty ? null : parts.join(', '),
      showDetails: false,
      onTap: () => context.push('/games/${group.game.igdbId}'),
      badge: group.hasReplays
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: Space.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: Space.xs,
                  children: [
                    Icon(
                      Icons.layers_outlined,
                      size: 14,
                      color: scheme.onSurface,
                    ),
                    Text(
                      '${group.totalEntries}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
