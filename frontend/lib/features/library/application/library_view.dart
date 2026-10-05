import '../../../core/design_system/game_status.dart';
import '../data/game_entry.dart';
import 'library_groups.dart';
import 'library_prefs.dart';

/// Filtra por status e ordena no cliente: a coleção já está toda carregada.
List<GameEntry> applyLibraryView(
  List<GameEntry> entries, {
  GameStatus? status,
  required LibrarySort sort,
}) {
  final filtered = status == null
      ? entries.toList()
      : entries.where((e) => e.status == status).toList();
  switch (sort) {
    case LibrarySort.recent:
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case LibrarySort.oldest:
      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    case LibrarySort.mostPlayed:
      // Sem horas vai para o fim, como no backend (NULLS LAST): um jogo sem registro
      // de horas não pode aparecer como "o mais jogado".
      filtered.sort((a, b) {
        final ha = a.hoursPlayed;
        final hb = b.hoursPlayed;
        if (ha == null && hb == null) return b.createdAt.compareTo(a.createdAt);
        if (ha == null) return 1;
        if (hb == null) return -1;
        final byHours = hb.compareTo(ha);
        return byHours != 0 ? byHours : b.createdAt.compareTo(a.createdAt);
      });
    case LibrarySort.name:
      filtered.sort((a, b) {
        final byName = foldText(a.game.name).compareTo(foldText(b.game.name));
        return byName != 0 ? byName : b.createdAt.compareTo(a.createdAt);
      });
  }
  return filtered;
}

/// Contagem por status da coleção inteira (independe do filtro ativo).
Map<GameStatus, int> countByStatus(List<GameEntry> entries) {
  final counts = {for (final s in GameStatus.values) s: 0};
  for (final e in entries) {
    counts[e.status] = counts[e.status]! + 1;
  }
  return counts;
}
