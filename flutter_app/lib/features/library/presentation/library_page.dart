import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/game_cover.dart';
import '../../../core/design_system/game_status.dart';
import '../../../core/design_system/status_chip.dart';
import '../../../core/design_system/tokens.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        actions: [
          const NotificationsBell(),
          PopupMenuButton<LibrarySort>(
            tooltip: 'Ordenar por ${prefs.sort.label}',
            icon: const Icon(Icons.sort),
            initialValue: prefs.sort,
            onSelected: prefsController.setSort,
            itemBuilder: (_) => [
              for (final sort in LibrarySort.values)
                CheckedPopupMenuItem(
                  value: sort,
                  checked: sort == prefs.sort,
                  child: Text(sort.label),
                ),
            ],
          ),
          IconButton(
            tooltip: prefs.grid ? 'Mostrar como lista' : 'Mostrar como grade',
            icon: Icon(prefs.grid ? Icons.view_list : Icons.grid_view),
            onPressed: () => prefsController.setGrid(!prefs.grid),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Tag própria: os FABs de todas as abas coexistem no IndexedStack.
        heroTag: 'fab-library',
        onPressed: _addGame,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar jogo'),
      ),
      body: AsyncContent<List<GameEntry>>(
        value: library,
        staleBanner: true,
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
            child: Column(
              children: [
                _Summary(
                  total: entries.length,
                  completed: counts[GameStatus.completed]!,
                ),
                _Filters(
                  selected: _filter,
                  counts: counts,
                  total: entries.length,
                  onSelected: (s) => setState(() => _filter = s),
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
          );
        },
      ),
    );
  }
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
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
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

class _Filters extends StatelessWidget {
  const _Filters({
    required this.selected,
    required this.counts,
    required this.total,
    required this.onSelected,
  });

  final GameStatus? selected;
  final Map<GameStatus, int> counts;
  final int total;
  final ValueChanged<GameStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: Row(
        spacing: Space.sm,
        children: [
          FilterChip(
            label: Text('Todos ($total)'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final s in GameStatus.values)
            FilterChip(
              avatar: Icon(s.icon, size: 18),
              label: Text('${s.label} (${counts[s]})'),
              selected: selected == s,
              onSelected: (_) => onSelected(selected == s ? null : s),
            ),
        ],
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

  /// Largura máxima desejada da capa (plano, seção 4.5: 100–140).
  static const _maxTileWidth = 140.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - 2 * Space.lg;
        final columns = (available / _maxTileWidth).ceil().clamp(1, 12);
        final rows = (entries.length / columns).ceil();
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 96),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/games/${entry.game.igdbId}'),
              child: GameCover(name: entry.game.name, url: entry.game.coverUrl),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: scheme.surface.withValues(alpha: 0.78),
                shape: const CircleBorder(),
                child: EntryMenuButton(entry: entry),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          entry.game.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: Space.xs),
        StatusChip(entry.status),
        const SizedBox(height: Space.xs),
        Text(
          entry.platform,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
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
      padding: const EdgeInsets.only(bottom: 96),
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
