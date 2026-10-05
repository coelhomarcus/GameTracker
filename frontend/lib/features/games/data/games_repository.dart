import 'package:dio/dio.dart';

import '../../../core/design_system/game_status.dart';
import '../../../core/network/app_exception.dart';
import 'game_models.dart';

abstract interface class GamesRepository {
  Future<List<GameSummary>> search(String term, {CancelToken? cancelToken});
  Future<Game> byIgdbId(int igdbId);
  Future<GameStats> stats(String gameId);
  Future<List<GamePlayer>> players(
    String gameId, {
    required GameStatus status,
    required PlayersScope scope,
  });
  Future<void> setFavorite(String gameId, {required bool favorite});
}

class RemoteGamesRepository implements GamesRepository {
  RemoteGamesRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<GameSummary>> search(String term, {CancelToken? cancelToken}) =>
      guardApi(() async {
        final r = await _dio.get<List<dynamic>>(
          '/games/search',
          queryParameters: {'q': term},
          cancelToken: cancelToken,
        );
        return r.data!
            .cast<Map<String, dynamic>>()
            .map(GameSummary.fromJson)
            .toList();
      });

  @override
  Future<Game> byIgdbId(int igdbId) => guardApi(() async {
    final r = await _dio.get<Map<String, dynamic>>('/games/igdb/$igdbId');
    return Game.fromJson(r.data!);
  });

  @override
  Future<GameStats> stats(String gameId) => guardApi(() async {
    final r = await _dio.get<Map<String, dynamic>>('/games/$gameId/stats');
    return GameStats.fromJson(r.data!);
  });

  @override
  Future<List<GamePlayer>> players(
    String gameId, {
    required GameStatus status,
    required PlayersScope scope,
  }) => guardApi(() async {
    final r = await _dio.get<List<dynamic>>(
      '/games/$gameId/players',
      queryParameters: {
        'status': status.apiValue,
        'scope': scope.apiValue,
        'limit': 10,
      },
    );
    return r.data!
        .cast<Map<String, dynamic>>()
        .map(GamePlayer.fromJson)
        .toList();
  });

  /// Favoritar/desfavoritar é idempotente no backend (204 em ambos os casos).
  @override
  Future<void> setFavorite(String gameId, {required bool favorite}) =>
      guardApi(() async {
        if (favorite) {
          await _dio.post<void>('/games/$gameId/favorite');
        } else {
          await _dio.delete<void>('/games/$gameId/favorite');
        }
      });
}
