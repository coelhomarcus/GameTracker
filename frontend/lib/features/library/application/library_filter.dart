import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/game_status.dart';
import '../data/game_entry.dart';
import 'library_controller.dart';
import 'library_groups.dart';
import 'library_prefs.dart';

/// Busca, status e plataforma da Biblioteca. Ficam só em memória: sobrevivem à troca de aba e são
/// descartados ao sair da conta. Modo de exibição e ordenação são outra coisa (persistidos).
class LibraryFilterController extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() {
    ref.watch(currentUserIdProvider);
    return const LibraryFilter();
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  /// Um status por vez; tocar no que já está escolhido volta para "Todos".
  void setStatus(GameStatus? status) =>
      state = state.copyWith(status: () => status);

  void toggleStatus(GameStatus status) =>
      setStatus(state.status == status ? null : status);

  void setPlatform(String? platformKey) =>
      state = state.copyWith(platformKey: () => platformKey);

  /// Remove busca, status e plataforma; modo de exibição e ordenação ficam.
  void clear() => state = const LibraryFilter();
}

final libraryFilterProvider =
    NotifierProvider<LibraryFilterController, LibraryFilter>(
      LibraryFilterController.new,
    );

/// A Biblioteca calculada. Só é recalculada quando a coleção, os filtros ou a ordenação mudam,
/// não a cada quadro; `null` enquanto a coleção não tem valor.
final libraryOverviewProvider = Provider<LibraryOverview?>((ref) {
  final List<GameEntry>? entries = ref.watch(libraryProvider).value;
  if (entries == null) return null;
  return buildLibraryOverview(
    entries,
    filter: ref.watch(libraryFilterProvider),
    sort: ref.watch(libraryPrefsProvider.select((p) => p.sort)),
  );
});

/// `igdbId` dos jogos que o usuário já tem na Biblioteca (com pelo menos um registro).
final libraryIgdbIdsProvider = Provider<Set<int>>((ref) {
  final List<GameEntry>? entries = ref.watch(libraryProvider).value;
  return {for (final e in entries ?? const <GameEntry>[]) e.game.igdbId};
});
