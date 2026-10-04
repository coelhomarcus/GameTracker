import '../../../core/dates/date_only.dart';
import '../../../core/design_system/game_status.dart';
import '../../games/data/game_models.dart';

/// Um playthrough. A chave é `id`, nunca `gameId`: o mesmo jogo pode ter vários registros
/// (replay), inclusive na mesma plataforma.
class GameEntry {
  const GameEntry({
    required this.id,
    required this.platform,
    required this.status,
    required this.createdAt,
    required this.game,
    this.startedAt,
    this.finishedAt,
    this.hoursPlayed,
    this.rating,
    this.notes,
  });

  factory GameEntry.fromJson(Map<String, dynamic> json) => GameEntry(
    id: json['id'] as String,
    platform: json['platform'] as String,
    status: GameStatus.fromApi(json['status'] as String),
    startedAt: json['startedAt'] == null
        ? null
        : DateOnly.parseApi(json['startedAt'] as String),
    finishedAt: json['finishedAt'] == null
        ? null
        : DateOnly.parseApi(json['finishedAt'] as String),
    // numeric(6,1): chega como string ("20.0"); aceita número por segurança.
    hoursPlayed: json['hoursPlayed'] == null
        ? null
        : double.parse(json['hoursPlayed'].toString()),
    rating: json['rating'] as int?,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    game: Game.fromJson(json['game'] as Map<String, dynamic>),
  );

  final String id;
  final String platform;
  final GameStatus status;
  final DateOnly? startedAt;
  final DateOnly? finishedAt;
  final double? hoursPlayed;
  final int? rating;
  final String? notes;

  /// Instante (não data de calendário): pode ser convertido para horário local.
  final DateTime createdAt;
  final Game game;
}

/// Valores do formulário de playthrough. `null` significa "sem valor".
class EntryDraft {
  const EntryDraft({
    required this.platform,
    required this.status,
    this.startedAt,
    this.finishedAt,
    this.hoursPlayed,
    this.rating,
    this.notes,
  });

  factory EntryDraft.fromEntry(GameEntry e) => EntryDraft(
    platform: e.platform,
    status: e.status,
    startedAt: e.startedAt,
    finishedAt: e.finishedAt,
    hoursPlayed: e.hoursPlayed,
    rating: e.rating,
    notes: e.notes,
  );

  final String platform;
  final GameStatus status;
  final DateOnly? startedAt;
  final DateOnly? finishedAt;
  final double? hoursPlayed;
  final int? rating;
  final String? notes;
}
