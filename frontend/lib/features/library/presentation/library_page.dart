import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/content_skeleton.dart';
import '../../../core/design_system/filter_toolbar.dart';
import '../../../core/design_system/game_card.dart';
import '../../../core/design_system/game_cover.dart';
import '../../../core/design_system/game_status.dart';
import '../../../core/design_system/page_container.dart';
import '../../../core/design_system/status_chip.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/primary_action.dart';
import '../../../core/data/hours.dart';
import '../../games/presentation/game_search_view.dart';
import '../../notifications/presentation/notifications_bell.dart';
import '../application/library_controller.dart';
import '../application/library_prefs.dart';
import '../application/library_view.dart';
import '../data/game_entry.dart';
import 'entry_actions.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  GameStatus? _filter;

  Future<void> _addGame() async {
    final game = await pickGame(context);
    if (game != null && mounted) {
      context.push('/games/${game.igdbId}/playthroughs/new');
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final prefs = ref.watch(libraryPrefsProvider);
    final prefsController = ref.read(libraryPrefsProvider.notifier);

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
          if (entries.isEmpty) {
            return EmptyView(
              icon: Icons.video_library_outlined,
              title: 'Sua biblioteca está vazia',
              message:
                  'Adicione os jogos que você joga, quer jogar ou já zerou.',
              action: FilledButton.icon(
                onPressed: _addGame,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar jogo'),
              ),
            );
          }
          final visible = applyLibraryView(
            entries,
            status: _filter,
            sort: prefs.sort,
          );
          final counts = countByStatus(entries);
          return RefreshIndicator(
            onRefresh: () async {
              try {
                await ref.read(libraryProvider.notifier).refresh();
              } catch (_) {
                // O erro aparece no banner de dados desatualizados.
              }
            },
            child: PageContainer(
              width: PageWidth.wide,
              child: Column(
                children: [
                  _Summary(
                    total: entries.length,
                    completed: counts[GameStatus.completed]!,
                  ),
                  FilterToolbar(
                    filters: _statusChips(counts, entries.length),
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
                  ),
                  const SizedBox(height: Space.sm),
                  Expanded(
                    child: visible.isEmpty
                        ? const _EmptyFilter()
                        : prefs.grid
                        ? _EntryGrid(entries: visible)
                        : _EntryList(entries: visible),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _statusChips(Map<GameStatus, int> counts, int total) => [
    FilterChip(
      label: Text('Todos ($total)'),
      selected: _filter == null,
      onSelected: (_) => setState(() => _filter = null),
    ),
    for (final s in GameStatus.values)
      FilterChip(
        avatar: Icon(s.icon, size: 18),
        label: Text('${s.label} (${counts[s]})'),
        selected: _filter == s,
        onSelected: (_) => setState(() => _filter = _filter == s ? null : s),
      ),
  ];
}

class _Summary extends StatelessWidget {
  const _Summary({required this.total, required this.completed});

  final int total;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final records = total == 1 ? '1 registro' : '$total registros';
    final done = completed == 1 ? '1 concluído' : '$completed concluídos';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$records · $done',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter();

  @override
  Widget build(BuildContext context) => ListView(
    children: const [
      SizedBox(height: 80),
      EmptyView(
        icon: Icons.filter_alt_off_outlined,
        title: 'Nenhum registro neste status',
      ),
    ],
  );
}

/// Linhas de altura intrínseca: a grade segue a largura do container, é lazy e não
/// quebra com texto ampliado.
class _EntryGrid extends StatelessWidget {
  const _EntryGrid({required this.entries});

  final List<GameEntry> entries;

  /// Largura máxima desejada da capa (docs/MIGRACAO_FLUTTER.md: 100–140).
  static const _maxTileWidth = 140.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final columns = (available / _maxTileWidth).ceil().clamp(1, 12);
        final rows = (entries.length / columns).ceil();
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(
            top: Space.sm,
            bottom: PrimaryAction.fabClearance,
          ),
          itemCount: rows,
          itemBuilder: (context, row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: Space.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) const SizedBox(width: Space.md),
                    Expanded(
                      child: row * columns + c < entries.length
                          ? _EntryTile(entry: entries[row * columns + c])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final GameEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GameCard(
      title: entry.game.name,
      coverUrl: entry.game.coverUrl,
      status: entry.status,
      caption: entry.platform,
      onTap: () => context.push('/games/${entry.game.igdbId}'),
      overlay: Material(
        color: scheme.surface.withValues(alpha: 0.78),
        shape: const CircleBorder(),
        child: EntryMenuButton(entry: entry),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries});

  final List<GameEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: PrimaryAction.fabClearance),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          leading: SizedBox(
            width: 48,
            child: GameCover(
              name: e.game.name,
              url: e.game.coverUrl,
              radius: 8,
            ),
          ),
          title: Text(
            e.game.name,
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
                StatusChip(e.status),
                Text(e.platform),
                if (e.hoursPlayed != null)
                  Text('${formatHours(e.hoursPlayed!)} h'),
                if (e.rating != null) Text('Nota ${e.rating}/10'),
              ],
            ),
          ),
          trailing: EntryMenuButton(entry: e),
          onTap: () => context.push('/games/${e.game.igdbId}'),
        );
      },
    );
  }
}
