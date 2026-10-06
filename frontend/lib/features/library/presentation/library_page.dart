import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/data/hours.dart';
import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/content_skeleton.dart';
import '../../../core/design_system/filter_toolbar.dart';
import '../../../core/design_system/game_card.dart';
import '../../../core/design_system/game_list_row.dart';
import '../../../core/design_system/game_shelf_item.dart';
import '../../../core/design_system/game_status.dart';
import '../../../core/design_system/page_header.dart';
import '../../../core/design_system/page_container.dart';
import '../../../core/design_system/primary_action.dart';
import '../../../core/design_system/section_header.dart';
import '../../../core/design_system/tokens.dart';
import '../../games/presentation/game_search_view.dart';
import '../../notifications/presentation/notifications_bell.dart';
import '../application/library_controller.dart';
import '../application/library_filter.dart';
import '../application/library_groups.dart';
import '../application/library_prefs.dart';
import '../data/game_entry.dart';
import 'entry_actions.dart';

/// Com texto este ampliado a grade de capas deixa de ser legível e a lista assume, sem mexer na
/// preferência salva.
const _listBeyondTextScale = 1.75;
final _unsetAccount = Object();

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _toolbarKey = GlobalKey();
  final _scrollController = ScrollController();
  Object? _scrollAccount = _unsetAccount;
  bool _searchFocused = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addGame() async {
    final game = await pickGame(context);
    if (game != null && mounted) {
      context.push('/games/${game.igdbId}/playthroughs/new');
    }
  }

  /// "Ver todos" da prateleira: filtra por Jogando e leva aos resultados.
  void _showAllPlaying() {
    ref.read(libraryFilterProvider.notifier).setStatus(GameStatus.playing);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _toolbarKey.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          duration: Motion.resolve(context, Motion.medium),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountId = ref.watch(currentUserIdProvider);
    if (!identical(_scrollAccount, _unsetAccount) &&
        _scrollAccount != accountId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      });
    }
    _scrollAccount = accountId;
    final library = ref.watch(libraryProvider);
    final overview = ref.watch(libraryOverviewProvider);
    final filter = ref.watch(libraryFilterProvider);
    final prefs = ref.watch(libraryPrefsProvider);
    final largeText =
        MediaQuery.textScalerOf(context).scale(14) / 14 >= _listBeyondTextScale;
    final addGame = PrimaryAction(
      heroTag: 'fab-library',
      icon: Icons.add,
      label: 'Adicionar jogo',
      onPressed: _addGame,
    );

    return Scaffold(
      appBar: PageHeader(
        title: 'Biblioteca',
        width: PageWidth.wide,
        action: addGame.headerButton(context),
        utilities: const [NotificationsBell()],
      ),
      floatingActionButton: addGame.fab(context),
      body: AsyncContent<List<GameEntry>>(
        value: library,
        staleBanner: true,
        loading: PageContainer(
          width: PageWidth.wide,
          child: prefs.grid && !largeText
              ? const ContentSkeleton.grid()
              : const ContentSkeleton.list(),
        ),
        onRetry: () => ref.invalidate(libraryProvider),
        data: (entries) {
          if (entries.isEmpty || overview == null) {
            return EmptyView(
              icon: Icons.video_library_outlined,
              title: 'Sua biblioteca começa com um jogo',
              message:
                  'Adicione os jogos que você joga, quer jogar ou já zerou.',
              action: FilledButton.icon(
                onPressed: () => context.go('/explore'),
                icon: const Icon(Icons.search),
                label: const Text('Encontrar jogo'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              try {
                await ref.read(libraryProvider.notifier).refresh();
              } catch (_) {
                // O erro aparece no banner de dados desatualizados.
              }
            },
            child: _LibraryScroll(
              overview: overview,
              filter: filter,
              prefs: prefs,
              toolbarKey: _toolbarKey,
              scrollController: _scrollController,
              scrollKey: PageStorageKey('library-scroll-$accountId'),
              searchFocused: _searchFocused,
              onSearchFocusChanged: (focused) {
                if (_searchFocused != focused) {
                  setState(() => _searchFocused = focused);
                }
              },
              onShowAllPlaying: _showAllPlaying,
            ),
          );
        },
      ),
    );
  }
}

class _LibraryScroll extends ConsumerWidget {
  const _LibraryScroll({
    required this.overview,
    required this.filter,
    required this.prefs,
    required this.toolbarKey,
    required this.scrollController,
    required this.scrollKey,
    required this.searchFocused,
    required this.onSearchFocusChanged,
    required this.onShowAllPlaying,
  });

  final LibraryOverview overview;
  final LibraryFilter filter;
  final LibraryPrefs prefs;
  final GlobalKey toolbarKey;
  final ScrollController scrollController;
  final PageStorageKey<String> scrollKey;
  final bool searchFocused;
  final ValueChanged<bool> onSearchFocusChanged;
  final VoidCallback onShowAllPlaying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.read(libraryFilterProvider.notifier);
    final prefsController = ref.read(libraryPrefsProvider.notifier);
    final largeText =
        MediaQuery.textScalerOf(context).scale(14) / 14 >= _listBeyondTextScale;
    final showGrid = prefs.grid && !largeText;
    final groups = overview.groups;

    return LayoutBuilder(
      builder: (context, box) {
        final insets = PageContainer.insetsFor(box.maxWidth, PageWidth.wide);
        SliverPadding padded(
          Widget sliver, {
          double top = 0,
          double bottom = 0,
        }) => SliverPadding(
          padding: insets.copyWith(top: top, bottom: bottom),
          sliver: sliver,
        );

        return CustomScrollView(
          key: scrollKey,
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            padded(
              SliverToBoxAdapter(child: _Summary(overview.summary)),
              top: Space.sm,
            ),
            if (!filter.isActive && !searchFocused && overview.shelf.isNotEmpty)
              padded(
                SliverToBoxAdapter(
                  child: _Shelf(
                    shelf: overview.shelf,
                    onShowAll: onShowAllPlaying,
                  ),
                ),
                top: Space.sm,
              ),
            padded(
              SliverToBoxAdapter(
                child: Column(
                  key: toolbarKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilterToolbar(
                      query: filter.query,
                      onQueryChanged: filters.setQuery,
                      searchHint: 'Buscar na biblioteca',
                      filters: [
                        FilterMenuButton<GameStatus>(
                          label: 'Status',
                          selected: filter.status,
                          onSelected: filters.setStatus,
                          options: [
                            (
                              value: null,
                              label: 'Todos (${overview.totalGames})',
                            ),
                            for (final s in GameStatus.values)
                              (
                                value: s,
                                label:
                                    '${s.label} (${overview.statusCounts[s]})',
                              ),
                          ],
                        ),
                        _PlatformMenu(
                          platforms: overview.platforms,
                          selectedKey: filter.platformKey,
                          onSelected: filters.setPlatform,
                        ),
                      ],
                      sortBuilder: (compact) => SortMenu<LibrarySort>(
                        values: LibrarySort.values,
                        selected: prefs.sort,
                        labelOf: (sort) => sort.label,
                        onSelected: prefsController.setSort,
                        compact: compact,
                      ),
                      viewToggle: ViewModeToggle(
                        grid: prefs.grid,
                        onChanged: prefsController.setGrid,
                      ),
                      onClear: filter.isActive ? filters.clear : null,
                      onSearchFocusChanged: onSearchFocusChanged,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.sm),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          groups.length == 1
                              ? '1 jogo encontrado'
                              : '${groups.length} jogos encontrados',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              top: Space.md,
            ),
            if (groups.isEmpty)
              padded(
                SliverToBoxAdapter(child: _EmptyFilter(onClear: filters.clear)),
                bottom: PrimaryAction.fabClearance,
              )
            else if (showGrid)
              padded(
                SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final geometry = GameGridGeometry.resolve(
                      context,
                      constraints.crossAxisExtent,
                    );
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: geometry.columns,
                        mainAxisSpacing: GameGridGeometry.spacing,
                        crossAxisSpacing: GameGridGeometry.spacing,
                        mainAxisExtent: geometry.cardExtent,
                      ),
                      itemCount: groups.length,
                      itemBuilder: (context, i) => _GroupTile(group: groups[i]),
                    );
                  },
                ),
                bottom: PrimaryAction.fabClearance,
              )
            else
              padded(
                SliverList.separated(
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _GroupRow(group: groups[i]),
                ),
                bottom: PrimaryAction.fabClearance,
              ),
          ],
        );
      },
    );
  }
}

String _plural(int n, String one, String many) =>
    n == 1 ? '1 $one' : '$n $many';

/// "24 jogos · 31 registros · 3 jogos em andamento".
class _Summary extends StatelessWidget {
  const _Summary(this.summary);

  final LibrarySummary summary;

  @override
  Widget build(BuildContext context) {
    final parts = [
      _plural(summary.games, 'jogo', 'jogos'),
      _plural(summary.records, 'registro', 'registros'),
      if (summary.playingGames > 0)
        _plural(
          summary.playingGames,
          'jogo em andamento',
          'jogos em andamento',
        ),
    ];
    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

/// Capas dos jogos em andamento, do mais recente ao mais antigo.
class _Shelf extends StatelessWidget {
  const _Shelf({required this.shelf, required this.onShowAll});

  final List<LibraryGroup> shelf;
  final VoidCallback onShowAll;

  static const _itemWidth = 224.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Jogando agora',
          actionLabel: 'Ver todos',
          onAction: onShowAll,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < shelf.length; i++) ...[
                if (i > 0) const SizedBox(width: Space.md),
                SizedBox(
                  width: _itemWidth,
                  child: GameShelfItem(
                    title: shelf[i].game.name,
                    coverUrl: shelf[i].game.coverUrl,
                    caption: _shelfCaption(shelf[i]),
                    onTap: () => _openGame(context, shelf[i].game.igdbId),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

void _openGame(BuildContext context, int igdbId) =>
    context.push('/games/$igdbId?tab=progress');

String _shelfCaption(LibraryGroup group) {
  final platforms = group.platforms.where((p) => p.trim().isNotEmpty).toList();
  return switch (platforms.length) {
    0 => 'Plataforma não informada',
    1 => platforms.single,
    _ => '${platforms.length} plataformas',
  };
}

String _collectionCaption(LibraryGroup group) {
  if (group.hasReplays) return group.recordsLabel!;
  final platforms = group.platforms.where((p) => p.trim().isNotEmpty);
  return platforms.isEmpty ? 'Plataforma não informada' : platforms.first;
}

/// Card da grade: a capa nunca precisa carregar sozinha a identificação do jogo.
class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final LibraryGroup group;

  @override
  Widget build(BuildContext context) {
    return GameCard.collection(
      title: group.game.name,
      coverUrl: group.game.coverUrl,
      status: group.singleStatus,
      caption: _collectionCaption(group),
      onTap: () => _openGame(context, group.game.igdbId),
      trailing: GameMenuButton(game: group.game),
    );
  }
}

/// Linha da lista: o modo para consultar informações.
class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group});

  final LibraryGroup group;

  @override
  Widget build(BuildContext context) {
    final platforms = group.platforms;
    final platformText = platforms.length > 2
        ? '${platforms.take(2).join(' · ')} +${platforms.length - 2}'
        : platforms.join(' · ');
    final hours = group.knownHours;
    // A nota é de um registro: só aparece quando o jogo tem um único.
    final single = group.totalEntries == 1 ? group.entries.single : null;
    final rating = single?.rating;
    return GameListRow(
      title: group.game.name,
      coverUrl: group.game.coverUrl,
      status: group.singleStatus,
      metadata: [
        if (platformText.isNotEmpty) platformText,
        ?group.recordsLabel,
        if (hours != null) '${formatHours(hours)} h',
        if (rating != null) 'Nota $rating/10',
      ],
      trailing: GameMenuButton(game: group.game),
      onTap: () => _openGame(context, group.game.igdbId),
    );
  }
}

/// Filtro de plataforma: uma por vez, a partir das plataformas dos registros.
class _PlatformMenu extends StatelessWidget {
  const _PlatformMenu({
    required this.platforms,
    required this.selectedKey,
    required this.onSelected,
  });

  final Map<String, String> platforms;
  final String? selectedKey;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => FilterMenuButton<String>(
    label: 'Plataforma',
    tooltip: 'Filtrar por plataforma',
    selected: selectedKey,
    onSelected: onSelected,
    options: [
      (value: null, label: 'Todas as plataformas'),
      for (final entry in platforms.entries)
        (value: entry.key, label: entry.value),
    ],
  );
}

class _EmptyFilter extends ConsumerWidget {
  const _EmptyFilter({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.xl),
    child: EmptyView(
      icon: Icons.filter_alt_off_outlined,
      title: 'Nenhum jogo com esses filtros',
      message: 'Tente outra busca ou limpe os filtros.',
      action: OutlinedButton(
        onPressed: onClear,
        child: const Text('Limpar filtros'),
      ),
    ),
  );
}
