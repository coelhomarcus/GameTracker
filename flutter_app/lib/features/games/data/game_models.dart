import '../../../core/design_system/game_status.dart';
import '../../../core/models/user_summary.dart';

List<String> _strings(Object? value) => List<String>.unmodifiable(
  (value as List<dynamic>? ?? const <dynamic>[]).map((e) => e as String),
);

/// Resultado de `GET /games/search`: ainda sem UUID interno.
class GameSummary {
  const GameSummary({
    required this.igdbId,
    required this.name,
    required this.platforms,
    required this.genres,
    this.coverUrl,
  });

  factory GameSummary.fromJson(Map<String, dynamic> json) => GameSummary(
    igdbId: json['igdbId'] as int,
    name: json['name'] as String,
    coverUrl: json['coverUrl'] as String?,
    platforms: _strings(json['platforms']),
    genres: _strings(json['genres']),
  );

  final int igdbId;
  final String name;
  final String? coverUrl;
  final List<String> platforms;
  final List<String> genres;
}

/// Jogo do cache do backend. `id` é o UUID interno; `igdbId` é o inteiro da IGDB
/// (docs/MIGRACAO_FLUTTER.md, regra 1): favoritar usa o UUID, criar registro usa o igdbId.
class Game {
  const Game({
    required this.id,
    required this.igdbId,
    required this.name,
    required this.screenshots,
    required this.platforms,
    required this.genres,
    this.coverUrl,
    this.summary,
    this.isFavoritedByMe = false,
  });

  factory Game.fromJson(Map<String, dynamic> json) => Game(
    id: json['id'] as String,
    igdbId: json['igdbId'] as int,
    name: json['name'] as String,
    coverUrl: json['coverUrl'] as String?,
    summary: json['summary'] as String?,
    screenshots: _strings(json['screenshots']),
    platforms: _strings(json['platforms']),
    genres: _strings(json['genres']),
    isFavoritedByMe: json['isFavoritedByMe'] as bool? ?? false,
  );

  final String id;
  final int igdbId;
  final String name;
  final String? coverUrl;
  final String? summary;
  final List<String> screenshots;
  final List<String> platforms;
  final List<String> genres;
  final bool isFavoritedByMe;

  Game copyWith({bool? isFavoritedByMe}) => Game(
    id: id,
    igdbId: igdbId,
    name: name,
    coverUrl: coverUrl,
    summary: summary,
    screenshots: screenshots,
    platforms: platforms,
    genres: genres,
    isFavoritedByMe: isFavoritedByMe ?? this.isFavoritedByMe,
  );
}

/// Contagem de **playthroughs** por status, não de pessoas: quem rejoga conta mais de uma vez.
class GameStats {
  const GameStats({
    required this.backlog,
    required this.playing,
    required this.completed,
    required this.dropped,
  });

  factory GameStats.fromJson(Map<String, dynamic> json) => GameStats(
    backlog: json['backlog'] as int? ?? 0,
    playing: json['playing'] as int? ?? 0,
    completed: json['completed'] as int? ?? 0,
    dropped: json['dropped'] as int? ?? 0,
  );

  final int backlog;
  final int playing;
  final int completed;
  final int dropped;

  int forStatus(GameStatus status) => switch (status) {
    GameStatus.backlog => backlog,
    GameStatus.playing => playing,
    GameStatus.completed => completed,
    GameStatus.dropped => dropped,
  };

  int get total => backlog + playing + completed + dropped;
}

class GamePlayer {
  const GamePlayer({
    required this.user,
    required this.status,
    this.hoursPlayed,
  });

  factory GamePlayer.fromJson(Map<String, dynamic> json) => GamePlayer(
    user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
    status: GameStatus.fromApi(json['status'] as String),
    hoursPlayed: json['hoursPlayed'] == null
        ? null
        : double.parse(json['hoursPlayed'].toString()),
  );

  final UserSummary user;
  final GameStatus status;
  final double? hoursPlayed;
}

enum PlayersScope {
  all('all'),
  following('following');

  const PlayersScope(this.apiValue);
  final String apiValue;
}
