import '../../../core/design_system/game_status.dart';

/// Dados de fixture da Etapa 2. Substituídos pelo repository real na Etapa 4.
class LibraryEntry {
  const LibraryEntry({
    required this.id,
    required this.igdbId,
    required this.name,
    required this.platform,
    required this.status,
    this.hoursPlayed,
    this.rating,
  });

  final String id;
  final int igdbId;
  final String name;
  final String platform;
  final GameStatus status;
  final double? hoursPlayed;
  final int? rating;
}

const libraryFixtures = <LibraryEntry>[
  LibraryEntry(
    id: 'e1',
    igdbId: 900001,
    name: 'Jogo Fixture Um',
    platform: 'PC',
    status: GameStatus.completed,
    hoursPlayed: 20.0,
    rating: 8,
  ),
  LibraryEntry(
    id: 'e2',
    igdbId: 900001,
    name: 'Jogo Fixture Um',
    platform: 'PC',
    status: GameStatus.backlog,
  ),
  LibraryEntry(
    id: 'e3',
    igdbId: 900002,
    name: 'Jogo Fixture Dois com um nome bem comprido para testar quebra',
    platform: 'PlayStation 5',
    status: GameStatus.playing,
    hoursPlayed: 0,
  ),
  LibraryEntry(
    id: 'e4',
    igdbId: 900003,
    name: 'Terceiro',
    platform: 'Switch',
    status: GameStatus.dropped,
    hoursPlayed: 3.5,
    rating: 4,
  ),
];
