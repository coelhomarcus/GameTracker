import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/post_models.dart';
import 'post_store.dart';

/// Árvore de comentários de um post. Curtir é otimista com rollback; criar é confirmado
/// pelo servidor e recarrega a árvore (sem inventar o comentário no cliente).
class CommentsController extends AsyncNotifier<List<Comment>> {
  CommentsController(this.postId);
  final String postId;

  final _likePending = <String>{};

  @override
  Future<List<Comment>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    _likePending.clear();
    final tree = await ref.watch(feedRepositoryProvider).comments(postId);
    _syncPostCount(tree);
    return tree;
  }

  void _syncPostCount(List<Comment> tree) => ref
      .read(postStoreProvider.notifier)
      .setCommentCount(postId, countComments(tree));

  /// Lança em falha; a tela mantém o texto digitado.
  Future<void> add(String content, {String? parentCommentId}) async {
    final userId = ref.read(currentUserIdProvider);
    await ref
        .read(feedRepositoryProvider)
        .addComment(postId, content, parentCommentId: parentCommentId);
    if (ref.read(currentUserIdProvider) != userId) return;
    final tree = await ref.read(feedRepositoryProvider).comments(postId);
    if (ref.read(currentUserIdProvider) != userId) return;
    _syncPostCount(tree);
    state = AsyncData(tree);
  }

  Future<void> toggleLike(String commentId) async {
    final tree = state.value;
    if (tree == null || _likePending.contains(commentId)) return;
    final before = findCommentInTree(tree, commentId);
    if (before == null) return;
    final userId = ref.read(currentUserIdProvider);

    _likePending.add(commentId);
    final target = !before.likedByMe;
    state = AsyncData(
      updateCommentInTree(
        tree,
        commentId,
        (c) => c.copyWith(
          likedByMe: target,
          likeCount: (c.likeCount + (target ? 1 : -1)).clamp(0, 1 << 30),
        ),
      ),
    );
    try {
      await ref
          .read(feedRepositoryProvider)
          .setCommentLike(commentId, liked: target);
    } catch (_) {
      if (ref.read(currentUserIdProvider) == userId && state.value != null) {
        state = AsyncData(
          updateCommentInTree(
            state.value!,
            commentId,
            (c) => c.copyWith(
              likedByMe: before.likedByMe,
              likeCount: before.likeCount,
            ),
          ),
        );
      }
      rethrow;
    } finally {
      _likePending.remove(commentId);
    }
  }
}

final commentsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<CommentsController, List<Comment>, String>(CommentsController.new);

/// Carrega um post pelo id e o coloca no [PostStore]. Quem exibe lê do store, então um
/// post já visto no feed aparece na hora enquanto isto revalida.
final postLoaderProvider = FutureProvider.autoDispose.family<void, String>((
  ref,
  id,
) async {
  ref.watch(currentUserIdProvider);
  final post = await ref.watch(feedRepositoryProvider).post(id);
  ref.read(postStoreProvider.notifier).upsert([post]);
});
