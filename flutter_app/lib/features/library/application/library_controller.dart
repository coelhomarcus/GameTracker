import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../games/application/game_providers.dart';
import '../data/game_entry.dart';

/// Coleção do usuário logado. É a fonte única da Biblioteca, da página de jogo e do
/// formulário: cada mutação aplica a resposta do servidor aqui, então todas as telas
/// concordam sem refetch. Descartado ao sair ou trocar de conta.
class LibraryController extends AsyncNotifier<List<GameEntry>> {
  @override
  Future<List<GameEntry>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.watch(libraryRepositoryProvider).listMine();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Mutações não têm retry automático: uma falha chega à tela, que mantém o formulário.
  Future<GameEntry> create(int igdbId, EntryDraft draft) async {
    final userId = ref.read(currentUserIdProvider);
    final created = await ref
        .read(libraryRepositoryProvider)
        .create(igdbId, draft);
    _apply(userId, (list) => [created, ...list]);
    return created;
  }

  Future<GameEntry> edit(GameEntry original, EntryDraft draft) async {
    final userId = ref.read(currentUserIdProvider);
    final updated = await ref
        .read(libraryRepositoryProvider)
        .update(original, draft);
    _apply(
      userId,
      (list) => [for (final e in list) e.id == updated.id ? updated : e],
    );
    return updated;
  }

  Future<void> remove(GameEntry entry) async {
    final userId = ref.read(currentUserIdProvider);
    await ref.read(libraryRepositoryProvider).delete(entry.id);
    _apply(userId, (list) => list.where((e) => e.id != entry.id).toList());
  }

  void _apply(
    String? userIdAtStart,
    List<GameEntry> Function(List<GameEntry>) change,
  ) {
    // A conta mudou enquanto a requisição estava no ar: não mexe na coleção da outra.
    if (ref.read(currentUserIdProvider) != userIdAtStart) return;
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
    } else {
      state = AsyncData(change(current));
    }
    // Estatísticas e jogadores contam playthroughs e vêm do servidor.
    ref.invalidate(gameStatsProvider);
    ref.invalidate(gamePlayersProvider);
  }
}

final libraryProvider =
    AsyncNotifierProvider<LibraryController, List<GameEntry>>(
      LibraryController.new,
    );
