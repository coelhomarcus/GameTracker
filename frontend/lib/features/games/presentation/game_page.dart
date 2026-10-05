import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/hours.dart';
import '../../../core/dates/date_only.dart';
import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/game_cover.dart';
import '../../../core/design_system/game_status.dart';
import '../../../core/design_system/page_container.dart';
import '../../../core/design_system/pinned_tab_bar.dart';
import '../../../core/design_system/section_header.dart';
import '../../../core/design_system/status_chip.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../../../core/network/error_messages.dart';
import '../../../core/network/image_url.dart';
import '../../../core/navigation/back_navigation.dart';
import '../../feed/presentation/post_slivers.dart';
import '../../library/application/library_controller.dart';
import '../../library/data/game_entry.dart';
import '../../library/presentation/entry_actions.dart';
import '../application/game_posts_controller.dart';
import '../application/game_providers.dart';
import '../data/game_models.dart';
import 'image_viewer.dart';

/// Página de jogo reconstruída pelo `igdbId` da rota (funciona em deep link e recarga).
/// A aba vem da rota (`?tab=progress`, `?tab=community`); cada aba carrega a sua parte, então a
/// falha de uma não derruba a página inteira.
class GamePage extends ConsumerWidget {
  const GamePage({super.key, required this.igdbId, this.tab});

  final int igdbId;

  /// `progress` ou `community` abrem essa aba; ausente ou desconhecido abre "Sobre".
  final String? tab;

  static int tabIndex(String? tab) => switch (tab) {
    'progress' => 1,
    'community' => 2,
    _ => 0,
  };

  static const _back = FallbackBackButton(fallback: '/library');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Link com id inválido: não há o que carregar, e repetir a consulta não ajuda.
    if (igdbId <= 0) {
      return Scaffold(
        appBar: AppBar(leading: _back),
        body: EmptyView(
          icon: Icons.search_off,
          title: 'Jogo não encontrado',
          message: 'O endereço deste jogo não é válido.',
          action: FilledButton(
            onPressed: () => context.go('/library'),
            child: const Text('Ir para a Biblioteca'),
          ),
        ),
      );
    }
    final game = ref.watch(gameControllerProvider(igdbId));
    return game.when(
      loading: () => Scaffold(
        appBar: AppBar(leading: _back),
        body: const LoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(leading: _back),
        body: ErrorView(
          message: describeError(error),
          onRetry: () => ref.invalidate(gameControllerProvider(igdbId)),
        ),
      ),
      data: (game) => _GameScaffold(game: game, tab: tab),
    );
  }
}

class _GameScaffold extends ConsumerStatefulWidget {
  const _GameScaffold({required this.game, required this.tab});

  final Game game;
  final String? tab;

  @override
  ConsumerState<_GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends ConsumerState<_GameScaffold>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: GamePage.tabIndex(widget.tab),
  )..addListener(_syncRoute);

  static const _communityTab = 2;

  /// Trocar de aba atualiza a rota, mas sem empilhar: `replace` reaproveita a página (e o estado)
  /// e não anima, então o botão de voltar continua levando a quem abriu o jogo.
  void _syncRoute() {
    if (_tabs.indexIsChanging) return;
    final target = _tabs.index;
    if (target == GamePage.tabIndex(widget.tab)) return;
    final query = switch (target) {
      1 => '?tab=progress',
      2 => '?tab=community',
      _ => '',
    };
    context.replace('/games/${widget.game.igdbId}$query');
  }

  @override
  void didUpdateWidget(_GameScaffold old) {
    super.didUpdateWidget(old);
    // A rota mudou por fora (link, histórico do navegador): a aba acompanha.
    final target = GamePage.tabIndex(widget.tab);
    if (target != _tabs.index) _tabs.animateTo(target);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(gameControllerProvider(widget.game.igdbId).notifier)
          .toggleFavorite();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _refresh() async {
    switch (_tabs.index) {
      case 1:
        try {
          await ref.read(libraryProvider.notifier).refresh();
        } catch (_) {
          // O erro aparece na própria aba.
        }
      case _communityTab:
        ref.invalidate(gameStatsProvider(widget.game.id));
        ref.invalidate(gamePlayersProvider);
        try {
          await ref
              .read(gamePostsControllerProvider(widget.game.id).notifier)
              .refresh();
        } catch (_) {
          // O erro aparece na lista de posts.
        }
    }
  }

  /// Pede a próxima página de posts perto do fim da rolagem (só na aba Comunidade).
  bool _onScroll(Notification notification) {
    if (_tabs.index != _communityTab) return false;
    return loadMorePostsOnScroll(
      notification,
      ref,
      gamePostsControllerProvider(widget.game.id),
      isMounted: () => mounted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final game =
        ref.watch(gameControllerProvider(widget.game.igdbId)).value ??
        widget.game;
    final library = ref.watch(libraryProvider);
    final mine = [
      for (final e in library.value ?? const <GameEntry>[])
        if (e.game.id == game.id) e,
    ]..sort(_newestFirst);

    return Scaffold(
      body: NotificationListener<Notification>(
        onNotification: _onScroll,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: LayoutBuilder(
            builder: (context, box) {
              final insets = PageContainer.insetsFor(
                box.maxWidth,
                PageWidth.reading,
              );
              return ListenableBuilder(
                listenable: _tabs,
                builder: (context, _) => CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      leading: GamePage._back,
                      title: Text(
                        game.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SliverPadding(
                      padding: insets.copyWith(top: Space.lg, bottom: Space.lg),
                      sliver: SliverToBoxAdapter(
                        child: _Hero(
                          game: game,
                          records: library.hasValue ? mine.length : null,
                          onFavorite: _toggleFavorite,
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: PinnedTabBarDelegate(
                        TabBar(
                          controller: _tabs,
                          tabs: const [
                            Tab(text: 'Sobre'),
                            Tab(text: 'Meu progresso'),
                            Tab(text: 'Comunidade'),
                          ],
                        ),
                        Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    ..._content(game, mine, library, insets),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    Game game,
    List<GameEntry> mine,
    AsyncValue<List<GameEntry>> library,
    EdgeInsets insets,
  ) {
    final padding = insets.copyWith(top: Space.lg, bottom: Space.xxl);
    return switch (_tabs.index) {
      1 => [
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(
            child: _ProgressSection(game: game, mine: mine, library: library),
          ),
        ),
      ],
      2 => _communitySlivers(game, insets),
      _ => [
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(child: _AboutSection(game: game)),
        ),
      ],
    };
  }

  List<Widget> _communitySlivers(Game game, EdgeInsets insets) {
    return [
      SliverPadding(
        padding: insets.copyWith(top: Space.lg),
        sliver: SliverToBoxAdapter(child: _CommunitySection(game: game)),
      ),
      ...postSlivers(
        ref: ref,
        provider: gamePostsControllerProvider(game.id),
        insets: insets,
        empty: const EmptyView(
          icon: Icons.forum_outlined,
          title: 'Ninguém publicou sobre este jogo',
          message: 'Seja a primeira pessoa a contar o que achou.',
        ),
      ),
    ];
  }
}

/// Do mais novo ao mais antigo, como na Biblioteca; o id desempata.
int _newestFirst(GameEntry a, GameEntry b) {
  final byDate = b.createdAt.compareTo(a.createdAt);
  return byDate != 0 ? byDate : b.id.compareTo(a.id);
}

/// Capa, título, plataformas, gêneros, favorito e a ação principal. Sem registros a ação é
/// "Adicionar à biblioteca"; com registros, "Novo registro" e quantos já existem.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.game,
    required this.records,
    required this.onFavorite,
  });

  final Game game;

  /// Registros do usuário neste jogo; `null` enquanto a coleção não carregou.
  final int? records;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = text.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final favorite = game.isFavoritedByMe;
    final count = records;
    final has = count != null && count > 0;

    return LayoutBuilder(
      builder: (context, box) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.lg,
        children: [
          SizedBox(
            width: box.maxWidth < 420 ? 96 : 128,
            child: GameCover(name: game.name, url: game.coverUrl),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    game.name,
                    style: text.headlineMedium,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (game.platforms.isNotEmpty) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    game.platforms.join(' · '),
                    style: muted,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (game.genres.isNotEmpty)
                  Text(
                    game.genres.join(' · '),
                    style: muted,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: Space.md),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.push(
                        '/games/${game.igdbId}/playthroughs/new',
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(
                        has || count == null
                            ? 'Novo registro'
                            : 'Adicionar à biblioteca',
                      ),
                    ),
                    IconButton(
                      tooltip: favorite ? 'Remover dos favoritos' : 'Favoritar',
                      isSelected: favorite,
                      icon: const Icon(Icons.favorite_border),
                      selectedIcon: Icon(
                        Icons.favorite,
                        color: context.domainColors.like,
                      ),
                      onPressed: onFavorite,
                    ),
                  ],
                ),
                if (has)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Text(
                      count == 1
                          ? 'Você tem 1 registro deste jogo'
                          : 'Você tem $count registros deste jogo',
                      style: muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Sinopse'),
        _Synopsis(summary: game.summary),
        if (game.platforms.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          const SectionHeader(title: 'Plataformas'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final platform in game.platforms)
                Chip(label: Text(platform)),
            ],
          ),
        ],
        if (game.genres.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          const SectionHeader(title: 'Gêneros'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final genre in game.genres) Chip(label: Text(genre)),
            ],
          ),
        ],
        if (game.screenshots.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          const SectionHeader(title: 'Screenshots'),
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
                  borderRadius: BorderRadius.circular(Radii.cover),
                  onTap: () => ImageViewerPage.open(
                    context,
                    urls: game.screenshots,
                    initialIndex: i,
                    title: 'Screenshot de ${game.name}',
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.cover),
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

/// Sinopse limitada a seis linhas, com "Ler mais" só quando o texto não cabe nelas.
class _Synopsis extends StatefulWidget {
  const _Synopsis({required this.summary});

  final String? summary;

  static const collapsedLines = 6;

  @override
  State<_Synopsis> createState() => _SynopsisState();
}

class _SynopsisState extends State<_Synopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary?.trim();
    if (summary == null || summary.isEmpty) {
      return const Text('Este jogo ainda não tem sinopse.');
    }
    final style = Theme.of(context).textTheme.bodyLarge;
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: summary, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: _Synopsis.collapsedLines,
        )..layout(maxWidth: box.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: Motion.resolve(context, Motion.medium),
              alignment: Alignment.topCenter,
              child: Text(
                summary,
                style: style,
                maxLines: _expanded ? null : _Synopsis.collapsedLines,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Ler menos' : 'Ler mais'),
              ),
          ],
        );
      },
    );
  }
}

/// Um card por registro (`entry.id`), do mais novo ao mais antigo. As notas pessoais só aparecem
/// aqui, na experiência do próprio usuário.
class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.game,
    required this.mine,
    required this.library,
  });

  final Game game;
  final List<GameEntry> mine;
  final AsyncValue<List<GameEntry>> library;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => AsyncContent<List<GameEntry>>(
        value: library,
        onRetry: () => ref.invalidate(libraryProvider),
        data: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mine.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Space.xl),
                child: EmptyView(
                  icon: Icons.bookmark_add_outlined,
                  title: 'Você ainda não registrou este jogo',
                  message:
                      'Crie um registro para acompanhar status, horas e nota.',
                ),
              ),
            for (final e in mine)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: _RecordCard(entry: e),
              ),
            const SizedBox(height: Space.sm),
            FilledButton.tonalIcon(
              onPressed: () =>
                  context.push('/games/${game.igdbId}/playthroughs/new'),
              icon: const Icon(Icons.add),
              label: Text(
                mine.isEmpty ? 'Novo registro' : 'Novo registro (replay)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.entry});

  final GameEntry entry;

  @override
  Widget build(BuildContext context) {
    final created = DateOnly.fromLocal(entry.createdAt.toLocal()).format();
    final details = [
      if (entry.startedAt != null) 'Início ${entry.startedAt!.format()}',
      if (entry.finishedAt != null) 'Fim ${entry.finishedAt!.format()}',
    ];
    final notes = entry.notes?.trim();
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Card(
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
              const SizedBox(height: Space.xs),
              Text(
                [...details, 'Criado em $created'].join(' · '),
                style: muted,
              ),
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

/// Estatísticas, jogadores e o convite para publicar. Os posts vêm logo abaixo, paginados.
class _CommunitySection extends ConsumerStatefulWidget {
  const _CommunitySection({required this.game});

  final Game game;

  @override
  ConsumerState<_CommunitySection> createState() => _CommunitySectionState();
}

class _CommunitySectionState extends ConsumerState<_CommunitySection> {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Registros da comunidade', style: text.titleMedium),
        const SizedBox(height: Space.sm),
        // Altura mínima (não fixa): os contadores quebram em várias linhas conforme a largura e o
        // tamanho do texto, e uma caixa fixa fazia o conteúdo seguinte ficar por cima deles.
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
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
        const SizedBox(height: Space.sm),
        Text(
          'Conta registros, não pessoas: quem rejoga aparece mais de uma vez.',
          style: text.bodySmall,
        ),
        const SizedBox(height: Space.xl),
        Text('Jogando agora', style: text.titleMedium),
        Text('Alguns dos jogadores, até 10.', style: text.bodySmall),
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
                    leading: UserAvatar(
                      name: p.user.displayName,
                      url: p.user.avatarUrl,
                    ),
                    title: Text(p.user.displayName),
                    subtitle: Text('@${p.user.username}'),
                    trailing: p.hoursPlayed == null
                        ? null
                        : Text('${formatHours(p.hoursPlayed!)} h'),
                    onTap: () => context.push('/users/${p.user.id}'),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: Space.xl),
        const SectionHeader(title: 'Posts'),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => context.push('/posts/new?igdbId=${game.igdbId}'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Publicar sobre este jogo'),
          ),
        ),
        const SizedBox(height: Space.md),
      ],
    );
  }
}
