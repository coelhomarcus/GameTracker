import '../../../core/design_system/game_status.dart';
import '../../games/data/game_models.dart';
import '../data/game_entry.dart';
import 'library_prefs.dart';

/// Texto comparável: sem diferença de caixa nem de acentos, espaços normalizados.
String foldText(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_folded[char] ?? char);
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

const _foldGroups = {
  'a': 'àáâãäåāăą',
  'c': 'çćč',
  'd': 'ď',
  'e': 'èéêëēėęě',
  'i': 'ìíîïīįı',
  'l': 'ł',
  'n': 'ñńň',
  'o': 'òóôõöøō',
  'r': 'ř',
  's': 'śšş',
  't': 'ť',
  'u': 'ùúûüūůű',
  'y': 'ýÿ',
  'z': 'źżž',
};

final _folded = {
  for (final group in _foldGroups.entries)
    for (final char in group.value.split('')) char: group.key,
  'ß': 'ss',
  'æ': 'ae',
  'œ': 'oe',
};

/// Busca, status e plataforma da Biblioteca. Plataforma é guardada já normalizada.
class LibraryFilter {
  const LibraryFilter({this.query = '', this.status, this.platformKey});

  final String query;
  final GameStatus? status;
  final String? platformKey;

  bool get isActive =>
      query.trim().isNotEmpty || status != null || platformKey != null;

  LibraryFilter copyWith({
    String? query,
    GameStatus? Function()? status,
    String? Function()? platformKey,
  }) => LibraryFilter(
    query: query ?? this.query,
    status: status != null ? status() : this.status,
    platformKey: platformKey != null ? platformKey() : this.platformKey,
  );
}

/// Um jogo da Biblioteca com os registros que satisfazem os filtros. Nunca funde registros:
/// cada replay continua sendo o seu próprio [GameEntry].
class LibraryGroup {
  const LibraryGroup({
    required this.game,
    required this.entries,
    required this.totalEntries,
  });

  final Game game;

  /// Registros que satisfazem os filtros, do mais novo ao mais antigo.
  final List<GameEntry> entries;

  /// Todos os registros do jogo, filtrados ou não.
  final int totalEntries;

  Set<GameStatus> get statuses => {for (final e in entries) e.status};

  /// O status, se todos os registros correspondentes têm o mesmo; `null` com vários.
  GameStatus? get singleStatus => statuses.length == 1 ? statuses.first : null;

  bool get mixedStatus => statuses.length > 1;

  /// Mais de um registro do jogo existe (mesmo que o filtro mostre só um).
  bool get hasReplays => totalEntries > 1;

  bool get isPartial => entries.length < totalEntries;

  /// Plataformas distintas (por texto normalizado), na ordem dos registros.
  List<String> get platforms {
    final seen = <String>{};
    return [
      for (final e in entries)
        if (seen.add(foldText(e.platform))) e.platform,
    ];
  }

  /// Soma das horas conhecidas; `null` se nenhum registro tem horas. Zero é um valor conhecido.
  double? get knownHours {
    double? sum;
    for (final e in entries) {
      final h = e.hoursPlayed;
      if (h != null) sum = (sum ?? 0) + h;
    }
    return sum;
  }

  DateTime get newestAddedAt =>
      entries.map((e) => e.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);

  DateTime get oldestAddedAt =>
      entries.map((e) => e.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);

  /// "2 registros" ou, com filtro parcial, "1 de 2 registros". Nulo para um registro só.
  String? get recordsLabel {
    if (totalEntries <= 1) return null;
    return isPartial
        ? '${entries.length} de $totalEntries registros'
        : '$totalEntries registros';
  }
}

class LibrarySummary {
  const LibrarySummary({
    required this.games,
    required this.records,
    required this.playingGames,
  });

  final int games;
  final int records;
  final int playingGames;
}

/// Tudo o que a Biblioteca mostra, calculado a partir dos registros.
class LibraryOverview {
  const LibraryOverview({
    required this.summary,
    required this.shelf,
    required this.statusCounts,
    required this.totalGames,
    required this.platforms,
    required this.groups,
  });

  /// Jogos únicos, registros e jogos com registro em andamento; sem filtro.
  final LibrarySummary summary;

  /// "Jogando agora": no máximo [shelfSize] jogos, pelo registro `playing` mais recente.
  final List<LibraryGroup> shelf;

  /// Jogos distintos por status depois de busca e plataforma, antes do status escolhido. Um
  /// jogo com registros em dois status entra nos dois: a soma não é o total de jogos.
  final Map<GameStatus, int> statusCounts;

  /// Jogos distintos depois de busca e plataforma, antes do status escolhido.
  final int totalGames;

  /// Plataformas dos registros: chave normalizada → texto como foi escrito pela primeira vez.
  final Map<String, String> platforms;

  final List<LibraryGroup> groups;

  static const shelfSize = 6;
}

int _compareNewestFirst(GameEntry a, GameEntry b) {
  final byDate = b.createdAt.compareTo(a.createdAt);
  return byDate != 0 ? byDate : b.id.compareTo(a.id);
}

LibraryOverview buildLibraryOverview(
  List<GameEntry> entries, {
  LibraryFilter filter = const LibraryFilter(),
  LibrarySort sort = LibrarySort.recent,
}) {
  // Todos os registros de cada jogo, do mais novo ao mais antigo.
  final byGame = <String, List<GameEntry>>{};
  for (final e in entries) {
    (byGame[e.game.id] ??= []).add(e);
  }
  for (final list in byGame.values) {
    list.sort(_compareNewestFirst);
  }

  final platforms = <String, String>{};
  for (final e in entries) {
    platforms.putIfAbsent(foldText(e.platform), () => e.platform);
  }

  final summary = LibrarySummary(
    games: byGame.length,
    records: entries.length,
    playingGames: byGame.values
        .where((list) => list.any((e) => e.status == GameStatus.playing))
        .length,
  );

  final shelf = <LibraryGroup>[
    for (final list in byGame.values)
      if (list.any((e) => e.status == GameStatus.playing))
        LibraryGroup(
          game: list.first.game,
          entries: [
            for (final e in list)
              if (e.status == GameStatus.playing) e,
          ],
          totalEntries: list.length,
        ),
  ]..sort((a, b) => _byNewest(a, b));

  // Busca e plataforma primeiro; o status entra só nos resultados, para que as contagens dos
  // chips mostrem o que cada um traria.
  final query = foldText(filter.query);
  final base = <String, List<GameEntry>>{};
  for (final list in byGame.values) {
    if (query.isNotEmpty && !foldText(list.first.game.name).contains(query)) {
      continue;
    }
    final kept = filter.platformKey == null
        ? list
        : [
            for (final e in list)
              if (foldText(e.platform) == filter.platformKey) e,
          ];
    if (kept.isNotEmpty) base[list.first.game.id] = kept;
  }

  final statusCounts = {for (final s in GameStatus.values) s: 0};
  for (final list in base.values) {
    for (final status in {for (final e in list) e.status}) {
      statusCounts[status] = statusCounts[status]! + 1;
    }
  }

  final groups = <LibraryGroup>[];
  for (final entry in base.entries) {
    final kept = filter.status == null
        ? entry.value
        : [
            for (final e in entry.value)
              if (e.status == filter.status) e,
          ];
    if (kept.isEmpty) continue;
    groups.add(
      LibraryGroup(
        game: kept.first.game,
        entries: kept,
        totalEntries: byGame[entry.key]!.length,
      ),
    );
  }
  groups.sort((a, b) => _compare(sort, a, b));

  return LibraryOverview(
    summary: summary,
    shelf: shelf.take(LibraryOverview.shelfSize).toList(),
    statusCounts: statusCounts,
    totalGames: base.length,
    platforms: Map.fromEntries(
      platforms.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
    groups: groups,
  );
}

int _byNewest(LibraryGroup a, LibraryGroup b) {
  final byDate = b.newestAddedAt.compareTo(a.newestAddedAt);
  return byDate != 0 ? byDate : _byTitle(a, b);
}

int _byTitle(LibraryGroup a, LibraryGroup b) {
  final byName = foldText(a.game.name).compareTo(foldText(b.game.name));
  return byName != 0 ? byName : a.game.id.compareTo(b.game.id);
}

/// As chaves de ordenação saem dos registros que passaram pelos filtros. Desempate: título e,
/// por fim, o id do jogo.
int _compare(LibrarySort sort, LibraryGroup a, LibraryGroup b) {
  final primary = switch (sort) {
    LibrarySort.recent => b.newestAddedAt.compareTo(a.newestAddedAt),
    LibrarySort.oldest => a.oldestAddedAt.compareTo(b.oldestAddedAt),
    LibrarySort.mostPlayed => _compareHours(a.knownHours, b.knownHours),
    LibrarySort.name => foldText(a.game.name).compareTo(foldText(b.game.name)),
  };
  return primary != 0 ? primary : _byTitle(a, b);
}

/// Mais horas primeiro; sem nenhuma hora conhecida vai para o fim, depois de zero.
int _compareHours(double? a, double? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}
