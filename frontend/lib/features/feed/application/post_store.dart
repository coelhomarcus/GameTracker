import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/user_summary.dart';
import '../../games/application/game_posts_controller.dart';
import '../data/post_models.dart';
import 'feed_controller.dart';

/// Fonte única dos posts carregados. Feed Geral, Seguindo, detalhe (e, nas próximas
/// etapas, perfis e posts do jogo) guardam só ids e leem o post daqui, então curtida e
/// contadores ficam iguais em todas as superfícies. Descartado ao sair ou trocar de conta.
class PostStore extends Notifier<Map<String, Post>> {
  final _likePending = <String>{};

  @override
  Map<String, Post> build() {
    ref.watch(currentUserIdProvider);
    _likePending.clear();
    return const {};
  }

  /// Dados do servidor substituem o que há no store.
  void upsert(Iterable<Post> posts) {
    state = {...state, for (final p in posts) p.id: p};
  }

  void _put(Post post) => state = {...state, post.id: post};

  bool isLikePending(String postId) => _likePending.contains(postId);

  /// Resposta imediata com rollback em erro. Uma alternância por vez por post: toques
  /// enquanto a anterior está em andamento são ignorados, então a ordem nunca se inverte.
  Future<void> toggleLike(String postId) async {
    final before = state[postId];
    if (before == null || _likePending.contains(postId)) return;
    final userId = ref.read(currentUserIdProvider);

    _likePending.add(postId);
    final target = !before.likedByMe;
    _put(
      before.copyWith(
        likedByMe: target,
        likeCount: math.max(0, before.likeCount + (target ? 1 : -1)),
      ),
    );
    try {
      await ref.read(feedRepositoryProvider).setLike(postId, liked: target);
    } catch (_) {
      if (ref.read(currentUserIdProvider) == userId) {
        final now = state[postId];
        if (now != null) {
          _put(
            now.copyWith(
              likedByMe: before.likedByMe,
              likeCount: before.likeCount,
            ),
          );
        }
      }
      rethrow;
    } finally {
      _likePending.remove(postId);
    }
  }

  /// Depois de editar o perfil, os posts já carregados do próprio usuário passam a mostrar o
  /// nome, o username e o avatar novos (o servidor devolveria isso numa nova consulta).
  void replaceAuthor(UserSummary author) {
    var changed = false;
    final next = <String, Post>{};
    for (final entry in state.entries) {
      if (entry.value.author.id == author.id) {
        next[entry.key] = entry.value.withAuthor(author);
        changed = true;
      } else {
        next[entry.key] = entry.value;
      }
    }
    if (changed) state = next;
  }

  /// Atualiza só o contador de comentários (depois de comentar ou de recarregar a árvore).
  void setCommentCount(String postId, int count) {
    final post = state[postId];
    if (post != null && post.commentCount != count) {
      _put(post.copyWith(commentCount: count));
    }
  }

  Future<Post> create({
    required String content,
    String? gameId,
    String? gameEntryId,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    final created = await ref
        .read(feedRepositoryProvider)
        .create(content: content, gameId: gameId, gameEntryId: gameEntryId);
    if (ref.read(currentUserIdProvider) == userId) {
      upsert([created]);
      // O próprio post aparece no Geral; o Seguindo exclui os posts do usuário.
      if (ref.exists(feedControllerProvider(FeedScope.general))) {
        ref
            .read(feedControllerProvider(FeedScope.general).notifier)
            .prepend(created.id);
      }
      // E na lista do jogo ao qual ficou vinculado, se ela estiver aberta.
      final gameId = created.game?.id;
      if (gameId != null && ref.exists(gamePostsControllerProvider(gameId))) {
        ref
            .read(gamePostsControllerProvider(gameId).notifier)
            .prepend(created.id);
      }
    }
    return created;
  }
}

final postStoreProvider = NotifierProvider<PostStore, Map<String, Post>>(
  PostStore.new,
);

/// Um post do store (ou `null` se ainda não foi carregado).
final postByIdProvider = Provider.autoDispose.family<Post?, String>(
  (ref, id) => ref.watch(postStoreProvider.select((posts) => posts[id])),
);
