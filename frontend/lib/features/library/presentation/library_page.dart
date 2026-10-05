import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/hours.dart';
import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/content_skeleton.dart';
import '../../../core/design_system/filter_toolbar.dart';
import '../../../core/design_system/game_card.dart';
import '../../../core/design_system/game_cover.dart';
import '../../../core/design_system/game_status.dart';
import '../../../core/design_system/page_container.dart';
import '../../../core/design_system/primary_action.dart';
import '../../../core/design_system/section_header.dart';
import '../../../core/design_system/status_chip.dart';
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

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _toolbarKey = GlobalKey();

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
    final library = ref.watch(libraryProvider);
    final overview = ref.watch(libraryOverviewProvider);
    final filter = ref.watch(libraryFilterProvider);
    final prefs = ref.watch(libraryPrefsProvider);
    final addGame = PrimaryAction(
      heroTag: 'fab-library',
      icon: Icons.add,
      label: 'Adicionar jogo',
      onPressed: _addGame,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        actions: [?addGame.headerButton(context), const NotificationsBell()],
      ),
      floatingActionButton: addGame.fab(context),
      body: AsyncContent<List<GameEntry>>(
        value: library,
        staleBanner: true,
        loading: PageContainer(
          width: PageWidth.wide,
          child: prefs.grid
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
    required this.onShowAllPlaying,
  });

  final LibraryOverview overview;
  final LibraryFilter filter;
  final LibraryPrefs prefs;
  final GlobalKey toolbarKey;
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
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            padded(
              SliverToBoxAdapter(child: _Summary(overview.summary)),
              top: Space.sm,
            ),
            if (!filter.isActive && overview.shelf.isNotEmpty)
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
                        FilterChip(
                          label: Text('Todos (${overview.totalGames})'),
                          selected: filter.status == null,
                          onSelected: (_) => filters.setStatus(null),
                        ),
                        for (final s in GameStatus.values)
                          FilterChip(
                            avatar: Icon(s.icon, size: 18),
                            label: Text(
                              '${s.label} (${overview.statusCounts[s]})',
                            ),
                            selected: filter.status == s,
                            onSelected: (_) => filters.toggleStatus(s),
                          ),
                        _PlatformMenu(
                          platforms: overview.platforms,
                          selectedKey: filter.platformKey,
                          onSelected: filters.setPlatform,
                        ),
                      ],
                      sort: SortMenu<LibrarySort>(
                        values: LibrarySort.values,
                        selected: prefs.sort,
                        labelOf: (sort) => sort.label,
                        onSelected: prefsController.setSort,
                      ),
                      viewToggle: ViewModeToggle(
                        grid: prefs.grid,
                        onChanged: prefsController.setGrid,
                      ),
                      onClear: filter.isActive ? filters.clear : null,
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
                  builder: (context, constraints) => SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: GameCard.columnsFor(
                        constraints.crossAxisExtent,
                      ),
                      mainAxisSpacing: Space.md,
                      crossAxisSpacing: Space.md,
                      childAspectRatio: 3 / 4,
                    ),
                    itemCount: groups.length,
                    itemBuilder: (context, i) => _GroupTile(group: groups[i]),
                  ),
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

  static const _coverWidth = 104.0;

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
        SizedBox(
          height: _coverWidth * 4 / 3,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shelf.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.md),
            itemBuilder: (context, i) => SizedBox(
              width: _coverWidth,
              child: GameCard(
                title: shelf[i].game.name,
                coverUrl: shelf[i].game.coverUrl,
                status: GameStatus.playing,
                showDetails: false,
                onTap: () => _openGame(context, shelf[i].game.igdbId),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

void _openGame(BuildContext context, int igdbId) =>
    context.push('/games/$igdbId?tab=progress');

/// Texto lido pelo leitor de tela quando a grade mostra só a capa.
String? _spokenCaption(LibraryGroup group) {
  final parts = [if (group.mixedStatus) 'Vários status', ?group.recordsLabel];
  return parts.isEmpty ? null : parts.join(', ');
}

/// Capa na grade: sem título nem dados fixos embaixo; só o indicador de replays.
class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final LibraryGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GameCard(
      title: group.game.name,
      coverUrl: group.game.coverUrl,
      status: group.singleStatus,
      caption: _spokenCaption(group),
      showDetails: false,
      onTap: () => _openGame(context, group.game.igdbId),
      badge: group.hasReplays ? _ReplayBadge(group.totalEntries) : null,
      overlay: Material(
        color: scheme.surface.withValues(alpha: 0.78),
        shape: const CircleBorder(),
        child: GameMenuButton(game: group.game),
      ),
    );
  }
}

class _ReplayBadge extends StatelessWidget {
  const _ReplayBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
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
            Icon(Icons.layers_outlined, size: 14, color: scheme.onSurface),
            Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurface),
            ),
          ],
        ),
      ),
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
    final meta = Theme.of(context).textTheme.bodyMedium;

    return ListTile(
      leading: SizedBox(
        width: 48,
        child: GameCover(
          name: group.game.name,
          url: group.game.coverUrl,
          radius: Radii.cover,
        ),
      ),
      title: Text(
        group.game.name,
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
            group.singleStatus == null
                ? const StatusChip.mixed()
                : StatusChip(group.singleStatus!),
            if (platformText.isNotEmpty) Text(platformText, style: meta),
            if (group.recordsLabel != null)
              Text(group.recordsLabel!, style: meta),
            if (hours != null) Text('${formatHours(hours)} h', style: meta),
            if (rating != null) Text('Nota $rating/10', style: meta),
          ],
        ),
      ),
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

  /// `null` não chega ao `onSelected` do menu (é o mesmo que dispensá-lo).
  static const _all = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = selectedKey;
    final label = selected == null
        ? 'Plataforma'
        : platforms[selected] ?? selected;
    return PopupMenuButton<String>(
      tooltip: 'Filtrar por plataforma',
      initialValue: selected ?? _all,
      onSelected: (key) => onSelected(key == _all ? null : key),
      itemBuilder: (_) => [
        const PopupMenuItem(value: _all, child: Text('Todas as plataformas')),
        for (final entry in platforms.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          widthFactor: 1,
          child: Chip(
            avatar: const Icon(Icons.videogame_asset_outlined, size: 18),
            label: Text(label),
            deleteIcon: const Icon(Icons.arrow_drop_down, size: 18),
            onDeleted: null,
            backgroundColor: selected == null
                ? null
                : scheme.secondaryContainer,
          ),
        ),
      ),
    );
  }
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
