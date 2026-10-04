import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

enum LibrarySort {
  recent('recent', 'Mais recentes'),
  oldest('oldest', 'Mais antigos'),
  mostPlayed('most_played', 'Mais jogados');

  const LibrarySort(this.key, this.label);
  final String key;
  final String label;

  static LibrarySort fromKey(String? key) => LibrarySort.values.firstWhere(
    (s) => s.key == key,
    orElse: () => LibrarySort.recent,
  );
}

class LibraryPrefs {
  const LibraryPrefs({this.grid = true, this.sort = LibrarySort.recent});
  final bool grid;
  final LibrarySort sort;
}

/// Modo de exibição e ordenação, persistidos no aparelho (não são segredo).
class LibraryPrefsController extends Notifier<LibraryPrefs> {
  static const _gridKey = 'library.grid';
  static const _sortKey = 'library.sort';

  @override
  LibraryPrefs build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return LibraryPrefs(
      grid: prefs.getBool(_gridKey) ?? true,
      sort: LibrarySort.fromKey(prefs.getString(_sortKey)),
    );
  }

  void setGrid(bool grid) {
    state = LibraryPrefs(grid: grid, sort: state.sort);
    ref.read(sharedPreferencesProvider).setBool(_gridKey, grid);
  }

  void setSort(LibrarySort sort) {
    state = LibraryPrefs(grid: state.grid, sort: sort);
    ref.read(sharedPreferencesProvider).setString(_sortKey, sort.key);
  }
}

final libraryPrefsProvider =
    NotifierProvider<LibraryPrefsController, LibraryPrefs>(
      LibraryPrefsController.new,
    );
