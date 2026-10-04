import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/game_status.dart';
import '../../profiles/application/profile_providers.dart';
import '../data/game_models.dart';

/// Debounce da busca (plano, seção 2.3) e tamanho mínimo do termo.
const searchDebounce = Duration(milliseconds: 400);
const searchMinChars = 2;

/// Busca de jogos. O termo é a chave: ao digitar mais, o provider anterior é
/// descartado, a espera do debounce é abandonada e a requisição em voo é cancelada.
final gameSearchProvider = FutureProvider.autoDispose
    .family<List<GameSummary>, String>((ref, query) async {
      final term = query.trim();
      if (term.length < searchMinChars) return const [];

      final cancelToken = CancelToken();
      ref.onDispose(() => cancelToken.cancel());
      await Future<void>.delayed(searchDebounce);
      if (cancelToken.isCancelled) return const [];

      return ref
          .watch(gamesRepositoryProvider)
          .search(term, cancelToken: cancelToken);
    });

/// Detalhe do jogo, reconstruído pelo `igdbId` (funciona em deep link e recarregamento).
class GameController extends AsyncNotifier<Game> {
  GameController(this.igdbId);
  final int igdbId;

  bool _togglePending = false;

  @override
  Future<Game> build() async {
    ref.watch(currentUserIdProvider);
    return ref.watch(gamesRepositoryProvider).byIgdbId(igdbId);
  }

  bool get isTogglingFavorite => _togglePending;

  /// Resposta imediata com rollback em erro. Uma alternância por vez por jogo.
  Future<void> toggleFavorite() async {
    final game = state.value;
    if (game == null || _togglePending) return;
    _togglePending = true;
    final target = !game.isFavoritedByMe;
    state = AsyncData(game.copyWith(isFavoritedByMe: target));
    try {
      await ref
          .read(gamesRepositoryProvider)
          .setFavorite(game.id, favorite: target);
      // Os favoritos mostrados nos perfis (inclusive o próprio) mudaram.
      ref.invalidate(profileFavoritesProvider);
    } catch (_) {
      state = AsyncData(game.copyWith(isFavoritedByMe: !target));
      rethrow;
    } finally {
      _togglePending = false;
    }
  }
}

final gameControllerProvider = AsyncNotifierProvider.autoDispose
    .family<GameController, Game, int>(GameController.new);

final gameStatsProvider = FutureProvider.autoDispose.family<GameStats, String>((
  ref,
  gameId,
) {
  ref.watch(currentUserIdProvider);
  return ref.watch(gamesRepositoryProvider).stats(gameId);
});

typedef PlayersQuery = ({String gameId, GameStatus status, PlayersScope scope});

final gamePlayersProvider = FutureProvider.autoDispose
    .family<List<GamePlayer>, PlayersQuery>((ref, q) {
      ref.watch(currentUserIdProvider);
      return ref
          .watch(gamesRepositoryProvider)
          .players(q.gameId, status: q.status, scope: q.scope);
    });
