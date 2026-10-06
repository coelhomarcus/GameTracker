import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/game_card.dart';
import '../../../core/design_system/game_catalog_row.dart';
import '../../../core/design_system/search_field.dart';
import '../../../core/design_system/tokens.dart';
import '../../library/application/library_filter.dart';
import '../application/game_providers.dart';
import '../data/game_models.dart';

/// Busca de jogos. No seletor de jogo (modal) traz o próprio campo; em Explorar a consulta vem de
/// fora ([query]) e só os resultados são desenhados. Termos curtos não consultam o servidor; erro é
/// diferente de "nenhum resultado".
class GameSearchView extends ConsumerStatefulWidget {
  const GameSearchView({
    super.key,
    required this.onOpen,
    this.onAdd,
    this.onOpenProgress,
    this.query,
    this.idle,
    this.autofocus = false,
  });

  final void Function(GameSummary game) onOpen;

  /// Quando informado, cada resultado ganha um botão para adicionar.
  final void Function(GameSummary game)? onAdd;

  /// Quando informado, jogos que já estão na Biblioteca mostram "Na biblioteca" em vez de
  /// "Adicionar", e o botão abre os registros.
  final void Function(GameSummary game)? onOpenProgress;

  /// Consulta controlada de fora: sem ela, a visão tem o próprio campo de busca.
  final String? query;

  /// O que mostrar enquanto o termo é curto demais para buscar (só com [query]).
  final Widget? idle;
  final bool autofocus;

  bool get _controlled => query != null;

  @override
  ConsumerState<GameSearchView> createState() => _GameSearchViewState();
}

class _GameSearchViewState extends ConsumerState<GameSearchView> {
  final _controller = TextEditingController();
  String _query = '';
  Set<int> _libraryIds = const {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = (widget._controlled ? widget.query! : _query).trim();
    // Lido aqui (e não no itemBuilder): `ref.watch` só vale durante o build deste widget.
    _libraryIds = widget.onOpenProgress == null
        ? const {}
        : ref.watch(libraryIgdbIdsProvider);
    if (widget._controlled) {
      return term.length < searchMinChars
          ? (widget.idle ?? _hint(context))
          : _results(term);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.lg,
            Space.sm,
          ),
          child: AppSearchField(
            controller: _controller,
            hintText: 'Buscar jogos',
            autofocus: widget.autofocus,
            onClear: () {
              _controller.clear();
              setState(() => _query = '');
            },
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: term.length < searchMinChars ? _hint(context) : _results(term),
        ),
      ],
    );
  }

  Widget _hint(BuildContext context) => const EmptyView(
    icon: Icons.search,
    title: 'Busque um jogo pelo nome',
    message: 'Digite pelo menos 2 letras.',
  );

  Widget _results(String term) {
    final results = ref.watch(gameSearchProvider(term));
    return AsyncContent<List<GameSummary>>(
      value: results,
      onRetry: () => ref.invalidate(gameSearchProvider(term)),
      data: (games) {
        if (games.isEmpty) {
          return EmptyView(
            icon: Icons.search_off,
            title: 'Nenhum jogo encontrado',
            message: 'Nada para "$term".',
          );
        }
        if (widget.onOpenProgress == null) {
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: Space.xl),
            itemCount: games.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _modalRow(games[i]),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final grid =
                constraints.maxWidth >= Breakpoints.medium && scale < 1.75;
            if (!grid) {
              return ListView.separated(
                key: const PageStorageKey('explore-games-list'),
                padding: const EdgeInsets.only(bottom: Space.xl),
                itemCount: games.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _GameResult(
                  game: games[i],
                  inLibrary: _libraryIds.contains(games[i].igdbId),
                  onOpen: widget.onOpen,
                  onAdd: widget.onAdd,
                  onOpenProgress: widget.onOpenProgress!,
                ),
              );
            }
            final geometry = GameGridGeometry.resolve(
              context,
              constraints.maxWidth,
            );
            return GridView.builder(
              key: const PageStorageKey('explore-games-grid'),
              padding: const EdgeInsets.only(top: Space.md, bottom: Space.xl),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: geometry.columns,
                mainAxisExtent: geometry.catalogCardExtent,
                mainAxisSpacing: GameGridGeometry.spacing,
                crossAxisSpacing: GameGridGeometry.spacing,
              ),
              itemCount: games.length,
              itemBuilder: (context, i) => _GameResult(
                game: games[i],
                inLibrary: _libraryIds.contains(games[i].igdbId),
                onOpen: widget.onOpen,
                onAdd: widget.onAdd,
                onOpenProgress: widget.onOpenProgress!,
                grid: true,
              ),
            );
          },
        );
      },
    );
  }

  /// Linha do seletor em modal: o toque ou o "+" escolhem o jogo.
  Widget _modalRow(GameSummary game) => GameCatalogRow(
    title: game.name,
    coverUrl: game.coverUrl,
    caption: _platformsOrUnknown(game.platforms),
    stackActionOnCompact: false,
    action: widget.onAdd == null
        ? null
        : IconButton(
            tooltip: 'Adicionar ${game.name} à biblioteca',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => widget.onAdd!(game),
          ),
    onTap: () => widget.onOpen(game),
  );
}

/// Até duas plataformas e o quanto resta: "Switch · Wii U +2".
String platformsSummary(List<String> platforms) => platforms.length > 2
    ? '${platforms.take(2).join(' · ')} +${platforms.length - 2}'
    : platforms.join(' · ');

String _platformsOrUnknown(List<String> platforms) => platforms.isEmpty
    ? 'Plataformas não informadas'
    : platformsSummary(platforms);

/// Resultado de busca em Explorar: o corpo abre o jogo; o botão adiciona ou abre os registros.
/// O botão fica abaixo do texto, para não faltar espaço com fonte ampliada.
class _GameResult extends StatelessWidget {
  const _GameResult({
    required this.game,
    required this.inLibrary,
    required this.onOpen,
    required this.onAdd,
    required this.onOpenProgress,
    this.grid = false,
  });

  final GameSummary game;
  final bool inLibrary;
  final void Function(GameSummary game) onOpen;
  final void Function(GameSummary game)? onAdd;
  final void Function(GameSummary game) onOpenProgress;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final action = inLibrary
        ? Tooltip(
            message: '${game.name} já está na biblioteca. Ver registros',
            child: OutlinedButton.icon(
              onPressed: () => onOpenProgress(game),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Na biblioteca'),
            ),
          )
        : Tooltip(
            message: 'Adicionar ${game.name} à biblioteca',
            child: FilledButton.tonalIcon(
              onPressed: onAdd == null ? null : () => onAdd!(game),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar'),
            ),
          );
    if (grid) {
      return GameCard.catalog(
        title: game.name,
        coverUrl: game.coverUrl,
        caption: _platformsOrUnknown(game.platforms),
        action: action,
        onTap: () => onOpen(game),
      );
    }
    return GameCatalogRow(
      title: game.name,
      coverUrl: game.coverUrl,
      caption: _platformsOrUnknown(game.platforms),
      action: action,
      onTap: () => onOpen(game),
    );
  }
}

/// Seletor de jogo em sheet. Devolve o jogo escolhido ou `null`.
Future<GameSummary?> pickGame(BuildContext context) {
  return showModalBottomSheet<GameSummary>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: GameSearchView(
        autofocus: true,
        onOpen: (game) => Navigator.of(context).pop(game),
        onAdd: (game) => Navigator.of(context).pop(game),
      ),
    ),
  );
}
