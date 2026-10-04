import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/post_models.dart';
import 'post_store.dart';

class FeedState {
  const FeedState({
    required this.ids,
    required this.nextCursor,
    this.loadingMore = false,
    this.loadMoreError,
  });

  /// Só ids, na ordem do servidor; o conteúdo vem do [PostStore].
  final List<String> ids;

  /// Cursor opaco da próxima página; `null` quando acabou.
  final String? nextCursor;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;

  FeedState copyWith({
    List<String>? ids,
    Object? nextCursor = _keep,
    bool? loadingMore,
    Object? loadMoreError = _keep,
  }) => FeedState(
    ids: ids ?? this.ids,
    nextCursor: identical(nextCursor, _keep)
        ? this.nextCursor
        : nextCursor as String?,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: identical(loadMoreError, _keep)
        ? this.loadMoreError
        : loadMoreError,
  );

  static const _keep = Object();
}

/// Feed de um escopo, paginado por cursor, sem duplicatas e com no máximo uma página
/// sendo carregada por vez.
class FeedController extends AsyncNotifier<FeedState> {
  FeedController(this.scope);
  final FeedScope scope;

  /// Idade máxima antes de revalidar ao voltar para o app (plano, seção 5.3).
  static const maxAge = Duration(seconds: 30);

  DateTime? _loadedAt;
  bool _stale = false;

  @override
  Future<FeedState> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const FeedState(ids: [], nextCursor: null);

    final page = await ref.watch(feedRepositoryProvider).feed(scope);
    _loadedAt = ref.read(clockProvider)();
    _stale = false;
    ref.read(postStoreProvider.notifier).upsert(page.items);
    return FeedState(
      ids: _dedupe(page.items.map((p) => p.id)),
      nextCursor: page.nextCursor,
    );
  }

  static List<String> _dedupe(Iterable<String> ids) => ids.toSet().toList();

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Algo que muda este feed aconteceu em outro lugar (ex.: a atividade automática de um
  /// registro, criada de forma assíncrona no backend). Revalida quando o usuário voltar a ele.
  void markStale() => _stale = true;

  void revalidateIfStale() {
    final loadedAt = _loadedAt;
    if (loadedAt == null || state.isLoading) return;
    final old = ref.read(clockProvider)().difference(loadedAt) > maxAge;
    if (_stale || old) ref.invalidateSelf();
  }

  /// Insere um post recém-criado pelo usuário no topo, sem refetch.
  void prepend(String postId) {
    final current = state.value;
    if (current == null || current.ids.contains(postId)) return;
    state = AsyncData(current.copyWith(ids: [postId, ...current.ids]));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final userId = ref.read(currentUserIdProvider);

    state = AsyncData(current.copyWith(loadingMore: true, loadMoreError: null));
    try {
      final page = await ref
          .read(feedRepositoryProvider)
          .feed(scope, cursor: current.nextCursor);
      if (ref.read(currentUserIdProvider) != userId) return;
      ref.read(postStoreProvider.notifier).upsert(page.items);
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          ids: _dedupe([...latest.ids, ...page.items.map((p) => p.id)]),
          nextCursor: page.nextCursor,
          loadingMore: false,
        ),
      );
    } catch (e) {
      if (ref.read(currentUserIdProvider) != userId) return;
      final latest = state.value ?? current;
      // Erro de rodapé recuperável: a lista já carregada continua na tela.
      state = AsyncData(latest.copyWith(loadingMore: false, loadMoreError: e));
    }
  }
}

final feedControllerProvider =
    AsyncNotifierProvider.family<FeedController, FeedState, FeedScope>(
      FeedController.new,
    );

/// Marca os feeds já carregados como desatualizados e revalida os que estão velhos.
class FeedRevalidator {
  FeedRevalidator(this._ref);
  final Ref _ref;

  void markStale() {
    for (final scope in FeedScope.values) {
      if (_ref.exists(feedControllerProvider(scope))) {
        _ref.read(feedControllerProvider(scope).notifier).markStale();
      }
    }
  }

  void revalidateIfStale() {
    for (final scope in FeedScope.values) {
      if (_ref.exists(feedControllerProvider(scope))) {
        _ref.read(feedControllerProvider(scope).notifier).revalidateIfStale();
      }
    }
  }
}

final feedRevalidatorProvider = Provider<FeedRevalidator>(FeedRevalidator.new);
