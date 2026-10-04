import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/game_cover.dart';
import '../../../core/design_system/tokens.dart';
import '../application/game_providers.dart';
import '../data/game_models.dart';

/// Busca de jogos: campo + resultados. Usada na aba Explorar e no seletor de jogo.
/// Termos curtos não consultam o servidor; erro é diferente de "nenhum resultado".
class GameSearchView extends ConsumerStatefulWidget {
  const GameSearchView({
    super.key,
    required this.onOpen,
    this.onAdd,
    this.autofocus = false,
  });

  final void Function(GameSummary game) onOpen;

  /// Quando informado, cada resultado ganha um botão "Adicionar".
  final void Function(GameSummary game)? onAdd;
  final bool autofocus;

  @override
  ConsumerState<GameSearchView> createState() => _GameSearchViewState();
}

class _GameSearchViewState extends ConsumerState<GameSearchView> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = _query.trim();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.lg,
            Space.sm,
          ),
          child: SearchBar(
            controller: _controller,
            autoFocus: widget.autofocus,
            hintText: 'Buscar jogos',
            leading: const Icon(Icons.search),
            trailing: [
              if (_query.isNotEmpty)
                IconButton(
                  tooltip: 'Limpar busca',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _query = '');
                  },
                ),
            ],
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
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: Space.xl),
          itemCount: games.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final game = games[i];
            return ListTile(
              leading: SizedBox(
                width: 48,
                child: GameCover(
                  name: game.name,
                  url: game.coverUrl,
                  radius: 8,
                ),
              ),
              title: Text(
                game.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: game.platforms.isEmpty
                  ? null
                  : Text(
                      game.platforms.take(4).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: widget.onAdd == null
                  ? null
                  : IconButton(
                      tooltip: 'Adicionar ${game.name} à biblioteca',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => widget.onAdd!(game),
                    ),
              onTap: () => widget.onOpen(game),
            );
          },
        );
      },
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
