import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/game_card.dart';
import '../../../core/design_system/game_status.dart';
import '../../../core/design_system/page_container.dart';
import '../../../core/design_system/section_header.dart';
import '../../../core/design_system/tokens.dart';
import '../../games/presentation/game_search_view.dart';
import '../../library/application/library_filter.dart';
import '../../notifications/presentation/notifications_bell.dart';
import '../../profiles/presentation/people_search_view.dart';
import '../application/explore_search.dart';

/// Explorar: uma barra para jogos e pessoas, com as abas Jogos e Pessoas abaixo. A consulta e a
/// aba ficam aqui (e sobrevivem a abrir um resultado e voltar); as visões só desenham resultados.
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key, this.scope});

  /// `people` abre a aba Pessoas; ausente ou desconhecido, Jogos.
  final String? scope;

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: ExploreScope.values.length,
    vsync: this,
    initialIndex: ExploreScope.fromParam(widget.scope).index,
  );

  ExploreScope get _scope => ExploreScope.values[_tabs.index];

  @override
  void didUpdateWidget(ExplorePage old) {
    super.didUpdateWidget(old);
    // `/explore?scope=people` com a página já aberta troca a aba. Voltar a `/explore` sem escopo
    // (tocar no destino ativo) não tira a pessoa da aba em que ela estava.
    if (widget.scope != null && widget.scope != old.scope) {
      _tabs.animateTo(ExploreScope.fromParam(widget.scope).index);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _remember(ExploreScope scope) => ref
      .read(recentSearchesProvider.notifier)
      .record(scope, ref.read(exploreQueryProvider));

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(exploreQueryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar'),
        actions: const [NotificationsBell()],
      ),
      body: PageContainer(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Space.sm, bottom: Space.sm),
              child: _SearchField(onSubmitted: () => _remember(_scope)),
            ),
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Jogos'),
                Tab(text: 'Pessoas'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  GameSearchView(
                    query: query,
                    idle: const _Home(scope: ExploreScope.games),
                    onOpen: (game) {
                      _remember(ExploreScope.games);
                      context.push('/games/${game.igdbId}');
                    },
                    onAdd: (game) {
                      _remember(ExploreScope.games);
                      context.push('/games/${game.igdbId}/playthroughs/new');
                    },
                    onOpenProgress: (game) {
                      _remember(ExploreScope.games);
                      context.push('/games/${game.igdbId}?tab=progress');
                    },
                  ),
                  PeopleSearchView(
                    query: query,
                    idle: const _Home(scope: ExploreScope.people),
                    onOpenProfile: (_) => _remember(ExploreScope.people),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A barra única. O texto é o do estado de Explorar: tocar numa pesquisa recente o preenche.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({required this.onSubmitted});

  final VoidCallback onSubmitted;

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final _controller = TextEditingController(
    text: ref.read(exploreQueryProvider),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(exploreQueryProvider, (_, query) {
      if (query != _controller.text) {
        _controller.value = TextEditingValue(
          text: query,
          selection: TextSelection.collapsed(offset: query.length),
        );
      }
    });
    final query = ref.watch(exploreQueryProvider);
    // O `SearchBar` do Material gera um nó externo (toque/foco) sem rótulo ao lado do campo
    // rotulado; juntá-los dá ao leitor de tela um único elemento "Buscar jogos ou pessoas".
    return MergeSemantics(
      child: SearchBar(
        controller: _controller,
        hintText: 'Buscar jogos ou pessoas',
        leading: const Icon(Icons.search),
        textInputAction: TextInputAction.search,
        trailing: [
          if (query.isNotEmpty)
            IconButton(
              tooltip: 'Limpar busca',
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(exploreQueryProvider.notifier).set(''),
            ),
        ],
        onChanged: ref.read(exploreQueryProvider.notifier).set,
        onSubmitted: (_) => widget.onSubmitted(),
      ),
    );
  }
}

/// Início de cada aba, enquanto não há termo para buscar: pesquisas recentes, o que o usuário está
/// jogando (só em Jogos) e um convite para a Comunidade. Sem nada disso, uma orientação curta.
class _Home extends ConsumerWidget {
  const _Home({required this.scope});

  final ExploreScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = scope == ExploreScope.games;
    final recents = ref.watch(recentSearchesProvider)[scope] ?? const [];
    final playing = games
        ? ref.watch(libraryOverviewProvider)?.shelf ?? const []
        : const [];
    return ListView(
      key: PageStorageKey('explore-home-${scope.name}'),
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xl),
      children: [
        if (recents.isNotEmpty) ...[
          SectionHeader(
            title: 'Pesquisas recentes',
            actionLabel: 'Limpar histórico',
            onAction: () =>
                ref.read(recentSearchesProvider.notifier).clear(scope),
          ),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              for (final term in recents)
                ActionChip(
                  avatar: const Icon(Icons.history, size: 18),
                  label: Text(term),
                  onPressed: () =>
                      ref.read(exploreQueryProvider.notifier).set(term),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
        ],
        if (playing.isNotEmpty) ...[
          const SectionHeader(title: 'Jogando agora'),
          SizedBox(
            height: 104 * 4 / 3,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: playing.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.md),
              itemBuilder: (context, i) => SizedBox(
                width: 104,
                child: GameCard.cover(
                  title: playing[i].game.name,
                  coverUrl: playing[i].game.coverUrl,
                  semanticDescription: GameStatus.playing.label,
                  onTap: () => context.push(
                    '/games/${playing[i].game.igdbId}?tab=progress',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
        ],
        if (recents.isEmpty && playing.isEmpty)
          EmptyView(
            icon: games ? Icons.search : Icons.group_outlined,
            title: games ? 'Busque um jogo pelo nome' : 'Encontre pessoas',
            message: games
                ? 'Digite pelo menos 2 letras.'
                : 'Busque pelo nome ou username. Digite pelo menos 2 letras.',
          ),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => context.go('/community'),
            icon: const Icon(Icons.forum_outlined),
            label: Text(
              games
                  ? 'Encontrar conversas na Comunidade'
                  : 'Conhecer a comunidade',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
