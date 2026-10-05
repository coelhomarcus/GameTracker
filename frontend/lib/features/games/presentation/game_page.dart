import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/hours.dart';
import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/game_cover.dart';
import '../../../core/design_system/game_status.dart';
import '../../../core/design_system/status_chip.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/network/error_messages.dart';
import '../../../core/network/image_url.dart';
import '../../library/application/library_controller.dart';
import '../../library/data/game_entry.dart';
import '../../library/presentation/entry_actions.dart';
import '../application/game_providers.dart';
import '../data/game_models.dart';
import 'image_viewer.dart';

/// Página de jogo reconstruída pelo `igdbId` da rota (funciona em deep link e recarga).
/// Cada aba carrega a sua parte: a falha de uma não derruba a página inteira.
class GamePage extends ConsumerWidget {
  const GamePage({super.key, required this.igdbId});

  final int igdbId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider(igdbId));
    return game.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: describeError(error),
          onRetry: () => ref.invalidate(gameControllerProvider(igdbId)),
        ),
      ),
      data: (game) => _GameScaffold(game: game),
    );
  }
}

class _GameScaffold extends ConsumerWidget {
  const _GameScaffold({required this.game});

  final Game game;

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(gameControllerProvider(game.igdbId).notifier)
          .toggleFavorite();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = game.isFavoritedByMe;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              title: Text(
                game.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  tooltip: favorite ? 'Remover dos favoritos' : 'Favoritar',
                  isSelected: favorite,
                  icon: const Icon(Icons.favorite_border),
                  selectedIcon: Icon(
                    Icons.favorite,
                    color: context.domainColors.like,
                  ),
                  onPressed: () => _toggleFavorite(context, ref),
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Sobre'),
                  Tab(text: 'Meu progresso'),
                  Tab(text: 'Comunidade'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _AboutTab(game: game),
              _ProgressTab(game: game),
              _CommunityTab(game: game),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.lg,
          children: [
            SizedBox(
              width: 120,
              child: GameCover(name: game.name, url: game.coverUrl),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.name, style: text.titleLarge),
                  if (game.platforms.isNotEmpty) ...[
                    const SizedBox(height: Space.sm),
                    Text(game.platforms.join(' · '), style: text.bodyMedium),
                  ],
                  const SizedBox(height: Space.md),
                  FilledButton.icon(
                    onPressed: () =>
                        context.push('/games/${game.igdbId}/playthroughs/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo playthrough'),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (game.genres.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final genre in game.genres) Chip(label: Text(genre)),
            ],
          ),
        ],
        const SizedBox(height: Space.xl),
        Text('Sinopse', style: text.titleMedium),
        const SizedBox(height: Space.sm),
        Text(game.summary ?? 'Este jogo ainda não tem sinopse.'),
        if (game.screenshots.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          Text('Screenshots', style: text.titleMedium),
          const SizedBox(height: Space.sm),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: game.screenshots.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.md),
              itemBuilder: (context, i) => Semantics(
                button: true,
                label:
                    'Abrir screenshot ${i + 1} de ${game.screenshots.length}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => ImageViewerPage.open(
                    context,
                    urls: game.screenshots,
                    initialIndex: i,
                    title: 'Screenshot de ${game.name}',
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        ImageUrls.resolve(game.screenshots[i])!,
                        fit: BoxFit.cover,
                        cacheWidth: 480,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressTab extends ConsumerWidget {
  const _ProgressTab({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    return AsyncContent<List<GameEntry>>(
      value: library,
      onRetry: () => ref.invalidate(libraryProvider),
      data: (all) {
        // Chave de coleção é o id do registro; o jogo pode ter vários (replay).
        final mine = all.where((e) => e.game.id == game.id).toList();
        return ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            if (mine.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Space.xl),
                child: EmptyView(
                  icon: Icons.bookmark_add_outlined,
                  title: 'Você ainda não registrou este jogo',
                  message: 'Crie um playthrough para acompanhar status, horas e nota.',
                ),
              ),
            for (final e in mine)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: _PlaythroughCard(entry: e),
              ),
            const SizedBox(height: Space.sm),
            FilledButton.tonalIcon(
              onPressed: () =>
                  context.push('/games/${game.igdbId}/playthroughs/new'),
              icon: const Icon(Icons.add),
              label: Text(
                mine.isEmpty ? 'Novo playthrough' : 'Novo playthrough (replay)',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlaythroughCard extends StatelessWidget {
  const _PlaythroughCard({required this.entry});

  final GameEntry entry;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (entry.startedAt != null) 'Início ${entry.startedAt!.format()}',
      if (entry.finishedAt != null) 'Fim ${entry.finishedAt!.format()}',
    ];
    final notes = entry.notes?.trim();
    return Card.filled(
      child: ListTile(
        onTap: () => context.push(
          '/games/${entry.game.igdbId}/playthroughs/${entry.id}/edit',
        ),
        title: Text(entry.platform),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: Space.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusChip(entry.status),
                  if (entry.hoursPlayed != null)
                    Text('${formatHours(entry.hoursPlayed!)} h'),
                  if (entry.rating != null) Text('Nota ${entry.rating}/10'),
                ],
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: Space.xs),
                Text(details.join(' · ')),
              ],
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: Space.xs),
                Text(notes, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        trailing: EntryMenuButton(entry: entry),
      ),
    );
  }
}

class _CommunityTab extends ConsumerStatefulWidget {
  const _CommunityTab({required this.game});

  final Game game;

  @override
  ConsumerState<_CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends ConsumerState<_CommunityTab> {
  PlayersScope _scope = PlayersScope.all;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final stats = ref.watch(gameStatsProvider(game.id));
    final players = ref.watch(
      gamePlayersProvider((
        gameId: game.id,
        status: GameStatus.playing,
        scope: _scope,
      )),
    );
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        Text('Playthroughs deste jogo', style: text.titleMedium),
        const SizedBox(height: Space.sm),
        SizedBox(
          height: 56,
          child: AsyncContent<GameStats>(
            value: stats,
            onRetry: () => ref.invalidate(gameStatsProvider(game.id)),
            loading: const Center(child: CircularProgressIndicator()),
            data: (s) => Wrap(
              spacing: Space.md,
              runSpacing: Space.sm,
              children: [
                for (final status in GameStatus.values)
                  Chip(
                    avatar: Icon(status.icon, size: 18),
                    label: Text(
                      '${s.forStatus(status)} ${status.label.toLowerCase()}',
                    ),
                  ),
              ],
            ),
          ),
        ),
        Text(
          'Conta registros, não pessoas: quem rejoga aparece mais de uma vez.',
          style: text.bodySmall,
        ),
        const SizedBox(height: Space.xl),
        Text('Jogando agora', style: text.titleMedium),
        const SizedBox(height: Space.sm),
        SegmentedButton<PlayersScope>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: PlayersScope.all, label: Text('Todos')),
            ButtonSegment(
              value: PlayersScope.following,
              label: Text('Quem eu sigo'),
            ),
          ],
          selected: {_scope},
          onSelectionChanged: (s) => setState(() => _scope = s.first),
        ),
        const SizedBox(height: Space.md),
        AsyncContent<List<GamePlayer>>(
          value: players,
          onRetry: () => ref.invalidate(gamePlayersProvider),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.lg),
                child: Text(
                  _scope == PlayersScope.following
                      ? 'Ninguém que você segue está jogando.'
                      : 'Ninguém está jogando agora.',
                ),
              );
            }
            return Column(
              children: [
                for (final p in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text(
                        p.user.displayName.characters.first.toUpperCase(),
                      ),
                    ),
                    title: Text(p.user.displayName),
                    subtitle: Text('@${p.user.username}'),
                    trailing: p.hoursPlayed == null
                        ? null
                        : Text('${formatHours(p.hoursPlayed!)} h'),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: Space.xl),
        const Text('Posts sobre este jogo chegam na Etapa 5.'),
      ],
    );
  }
}
