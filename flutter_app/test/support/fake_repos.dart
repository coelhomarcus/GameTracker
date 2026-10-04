import 'dart:async';

import 'package:dio/dio.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/features/games/data/game_models.dart';
import 'package:gametracker/features/games/data/games_repository.dart';
import 'package:gametracker/features/library/data/game_entry.dart';
import 'package:gametracker/features/library/data/library_repository.dart';

Game fakeGame({
  int igdbId = 900001,
  String name = 'Jogo Fixture Um',
  bool favorite = false,
  List<String>? platforms,
}) => Game(
  id: 'g-$igdbId',
  igdbId: igdbId,
  name: name,
  screenshots: const [],
  platforms: platforms ?? const ['PC', 'PlayStation 5'],
  genres: const ['RPG'],
  summary: 'Sinopse de teste.',
  isFavoritedByMe: favorite,
);

GameEntry fakeEntry({
  String id = 'e1',
  Game? game,
  String platform = 'PC',
  GameStatus status = GameStatus.backlog,
  double? hours,
  int? rating,
  DateTime? createdAt,
}) => GameEntry(
  id: id,
  platform: platform,
  status: status,
  hoursPlayed: hours,
  rating: rating,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  game: game ?? fakeGame(),
);

class FakeLibraryRepository implements LibraryRepository {
  FakeLibraryRepository([List<GameEntry>? initial]) : entries = [...?initial];

  List<GameEntry> entries;
  Object? listError;
  Object? mutationError;
  Completer<void>? mutationGate;
  int listCalls = 0;
  final created = <(int, EntryDraft)>[];
  final updated = <(String, EntryDraft)>[];
  final deleted = <String>[];
  int _seq = 0;

  @override
  Future<List<GameEntry>> listMine() async {
    listCalls++;
    final error = listError;
    if (error != null) throw error;
    return [...entries];
  }

  @override
  Future<GameEntry> create(int igdbId, EntryDraft draft) async {
    await mutationGate?.future;
    final error = mutationError;
    if (error != null) throw error;
    created.add((igdbId, draft));
    final entry = GameEntry(
      id: 'new${_seq++}',
      platform: draft.platform,
      status: draft.status,
      startedAt: draft.startedAt,
      finishedAt: draft.finishedAt,
      hoursPlayed: draft.hoursPlayed,
      rating: draft.rating,
      notes: draft.notes,
      createdAt: DateTime.utc(2026, 6, 1).add(Duration(minutes: _seq)),
      game: fakeGame(igdbId: igdbId),
    );
    entries = [entry, ...entries];
    return entry;
  }

  @override
  Future<GameEntry> update(GameEntry original, EntryDraft edited) async {
    await mutationGate?.future;
    final error = mutationError;
    if (error != null) throw error;
    updated.add((original.id, edited));
    final entry = GameEntry(
      id: original.id,
      platform: edited.platform,
      status: edited.status,
      startedAt: edited.startedAt,
      finishedAt: edited.finishedAt,
      hoursPlayed: edited.hoursPlayed,
      rating: edited.rating,
      notes: edited.notes,
      createdAt: original.createdAt,
      game: original.game,
    );
    entries = [for (final e in entries) e.id == original.id ? entry : e];
    return entry;
  }

  @override
  Future<void> delete(String entryId) async {
    await mutationGate?.future;
    final error = mutationError;
    if (error != null) throw error;
    deleted.add(entryId);
    entries = entries.where((e) => e.id != entryId).toList();
  }
}

class FakeGamesRepository implements GamesRepository {
  FakeGamesRepository({Map<int, Game>? games})
    : games = games ?? {900001: fakeGame()};

  Map<int, Game> games;
  Object? searchError;
  Object? gameError;
  Object? favoriteError;
  Completer<void>? favoriteGate;
  GameStats statsResult = const GameStats(
    backlog: 1,
    playing: 2,
    completed: 3,
    dropped: 0,
  );
  List<GamePlayer> playersResult = const [];
  final searches = <String>[];
  final favoriteCalls = <(String, bool)>[];
  int statsCalls = 0;
  int cancelledSearches = 0;
  List<GameSummary> searchResult = const [];

  @override
  Future<List<GameSummary>> search(
    String term, {
    CancelToken? cancelToken,
  }) async {
    searches.add(term);
    cancelToken?.whenCancel.then((_) => cancelledSearches++);
    final error = searchError;
    if (error != null) throw error;
    return searchResult;
  }

  @override
  Future<Game> byIgdbId(int igdbId) async {
    final error = gameError;
    if (error != null) throw error;
    return games[igdbId]!;
  }

  @override
  Future<GameStats> stats(String gameId) async {
    statsCalls++;
    return statsResult;
  }

  @override
  Future<List<GamePlayer>> players(
    String gameId, {
    required GameStatus status,
    required PlayersScope scope,
  }) async => playersResult;

  @override
  Future<void> setFavorite(String gameId, {required bool favorite}) async {
    favoriteCalls.add((gameId, favorite));
    await favoriteGate?.future;
    final error = favoriteError;
    if (error != null) throw error;
  }
}
