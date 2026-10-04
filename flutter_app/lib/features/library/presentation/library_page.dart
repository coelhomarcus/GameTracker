import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/game_cover.dart';
import '../../../core/design_system/game_status.dart';
import '../../../core/design_system/status_chip.dart';
import '../../../core/design_system/tokens.dart';
import '../data/library_fixtures.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  GameStatus? _filter;
  bool _grid = true;

  @override
  Widget build(BuildContext context) {
    final entries = libraryFixtures
        .where((e) => _filter == null || e.status == _filter)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        actions: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.grid_view),
                tooltip: 'Grade',
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.view_list),
                tooltip: 'Lista',
              ),
            ],
            selected: {_grid},
            onSelectionChanged: (s) => setState(() => _grid = s.first),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notificações',
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Adicionar jogo'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Row(
              spacing: Space.sm,
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final s in GameStatus.values)
                  FilterChip(
                    avatar: Icon(s.icon, size: 18),
                    label: Text(s.label),
                    selected: _filter == s,
                    onSelected: (_) =>
                        setState(() => _filter = _filter == s ? null : s),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('Nenhum jogo neste status.'))
                : _grid
                ? _GridView(entries: entries)
                : _ListView(entries: entries),
          ),
        ],
      ),
    );
  }
}

class _GridView extends StatelessWidget {
  const _GridView({required this.entries});
  final List<LibraryEntry> entries;

  /// Largura máxima desejada da capa (plano, seção 4.5: 100–140).
  static const _maxTileWidth = 140.0;

  @override
  Widget build(BuildContext context) {
    // Linhas com altura intrínseca: a grade segue a largura do container e
    // continua lazy, sem proporção fixa que quebre com texto ampliado.
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - 2 * Space.lg;
        final columns = (available / _maxTileWidth).ceil().clamp(1, 12);
        final rows = (entries.length / columns).ceil();
        return ListView.builder(
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
                          ? _GameTile(entry: entries[row * columns + c])
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

class _GameTile extends StatelessWidget {
  const _GameTile({required this.entry});
  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/games/${entry.igdbId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GameCover(name: entry.name),
          const SizedBox(height: Space.sm),
          Text(
            entry.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: Space.xs),
          StatusChip(entry.status),
        ],
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.entries});
  final List<LibraryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          leading: SizedBox(
            width: 48,
            child: GameCover(name: e.name, radius: 8),
          ),
          title: Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis),
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
                  Text(
                    '${e.hoursPlayed!.toStringAsFixed(1).replaceAll('.', ',')} h',
                  ),
                if (e.rating != null) Text('Nota ${e.rating}/10'),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'Ações do registro',
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'status', child: Text('Alterar status')),
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'remove', child: Text('Remover')),
            ],
          ),
          onTap: () => context.push('/games/${e.igdbId}'),
        );
      },
    );
  }
}
