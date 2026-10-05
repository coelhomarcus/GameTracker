import 'dart:async';

import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/core/models/user_summary.dart';
import 'package:gametracker/features/feed/data/feed_repository.dart';
import 'package:gametracker/features/feed/data/post_models.dart';
import 'package:gametracker/features/games/data/game_models.dart';

const ana = UserSummary(id: 'u-ana', username: 'ana', name: 'Ana');
const beto = UserSummary(id: 'u-beto', username: 'beto');

Post fakePost({
  String id = 'p1',
  UserSummary author = beto,
  String content = 'Conteúdo do post',
  PostType type = PostType.status,
  GameStatus? activityStatus,
  Game? game,
  int likes = 0,
  int comments = 0,
  bool liked = false,
  DateTime? createdAt,
}) => Post(
  id: id,
  author: author,
  content: content,
  type: type,
  activityStatus: activityStatus,
  game: game,
  createdAt: createdAt ?? DateTime.utc(2026, 6, 1),
  likeCount: likes,
  commentCount: comments,
  likedByMe: liked,
);

Comment fakeComment({
  String id = 'c1',
  String postId = 'p1',
  UserSummary author = beto,
  String content = 'Comentário',
  int likes = 0,
  bool liked = false,
  List<Comment> replies = const [],
  String? parent,
}) => Comment(
  id: id,
  postId: postId,
  author: author,
  content: content,
  createdAt: DateTime.utc(2026, 6, 1),
  likeCount: likes,
  likedByMe: liked,
  replies: replies,
  parentCommentId: parent,
);

/// Feed falso que pagina de verdade, com cursor `cN` (índice inicial da próxima página).
class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository({
    List<Post>? general,
    List<Post>? following,
    this.pageSize = 2,
  }) : feeds = {
         FeedScope.general: [...?general],
         FeedScope.following: [...?following],
       };

  final Map<FeedScope, List<Post>> feeds;
  final int pageSize;

  final feedCalls = <(FeedScope, String?)>[];
  final likeCalls = <(String, bool)>[];
  final commentLikeCalls = <(String, bool)>[];
  final created = <({String content, String? gameId, String? gameEntryId})>[];
  final addedComments = <({String postId, String content, String? parent})>[];
  Map<String, Post> posts = {};
  Map<String, List<Comment>> commentTrees = {};

  Object? feedError;
  Object? pageTwoError;
  Object? likeError;
  Object? commentError;
  Object? createError;
  Object? postError;
  Object? commentsError;
  Completer<void>? feedGate;
  Completer<void>? likeGate;
  Completer<void>? commentGate;

  /// Se definido, a página seguinte devolve este item repetido (o feed mudou entre páginas).
  Post? duplicateOnNextPage;

  @override
  Future<PostPage> feed(FeedScope scope, {String? cursor}) async {
    feedCalls.add((scope, cursor));
    await feedGate?.future;
    final error = feedError;
    if (error != null) throw error;
    if (cursor != null) {
      final pageError = pageTwoError;
      if (pageError != null) throw pageError;
    }
    final all = feeds[scope]!;
    final start = cursor == null ? 0 : int.parse(cursor.substring(1));
    final end = (start + pageSize).clamp(0, all.length);
    final items = [
      if (cursor != null && duplicateOnNextPage != null) duplicateOnNextPage!,
      ...all.sublist(start, end),
    ];
    return PostPage(
      items: items,
      nextCursor: end < all.length ? 'c$end' : null,
    );
  }

  /// Posts por jogo (chave: UUID do jogo) e as chamadas feitas, com o cursor.
  final gamePostLists = <String, List<Post>>{};
  final gamePostCalls = <(String, String?)>[];
  Completer<void>? gamePostsGate;

  @override
  Future<PostPage> gamePosts(String gameId, {String? cursor}) async {
    gamePostCalls.add((gameId, cursor));
    await gamePostsGate?.future;
    final error = feedError;
    if (error != null) throw error;
    if (cursor != null) {
      final pageError = pageTwoError;
      if (pageError != null) throw pageError;
    }
    final all = gamePostLists[gameId] ?? const <Post>[];
    final start = cursor == null ? 0 : int.parse(cursor.substring(1));
    final end = (start + pageSize).clamp(0, all.length);
    return PostPage(
      items: all.sublist(start, end),
      nextCursor: end < all.length ? 'c$end' : null,
    );
  }

  /// Posts por perfil, na chave `<userId>:activity` ou `<userId>:post`.
  final userPostLists = <String, List<Post>>{};
  final userPostCalls = <(String, bool, String?)>[];

  @override
  Future<PostPage> userPosts(
    String userId, {
    required bool activities,
    String? cursor,
  }) async {
    userPostCalls.add((userId, activities, cursor));
    final error = feedError;
    if (error != null) throw error;
    final all =
        userPostLists['$userId:${activities ? 'activity' : 'post'}'] ??
        const <Post>[];
    final start = cursor == null ? 0 : int.parse(cursor.substring(1));
    final end = (start + pageSize).clamp(0, all.length);
    return PostPage(
      items: all.sublist(start, end),
      nextCursor: end < all.length ? 'c$end' : null,
    );
  }

  @override
  Future<Post> post(String id) async {
    final error = postError;
    if (error != null) throw error;
    final post =
        posts[id] ??
        feeds.values.expand((l) => l).where((p) => p.id == id).firstOrNull;
    if (post == null) throw StateError('post $id não existe no fake');
    return post;
  }

  @override
  Future<Post> create({
    required String content,
    String? gameId,
    String? gameEntryId,
  }) async {
    final error = createError;
    if (error != null) throw error;
    created.add((content: content, gameId: gameId, gameEntryId: gameEntryId));
    final post = fakePost(
      id: 'new${created.length}',
      author: ana,
      content: content,
      // O backend devolve o jogo do vínculo; o falso só sabe o UUID.
      game: gameId == null
          ? null
          : Game(
              id: gameId,
              igdbId: 0,
              name: 'Jogo $gameId',
              screenshots: const [],
              platforms: const [],
              genres: const [],
            ),
    );
    posts[post.id] = post;
    feeds[FeedScope.general] = [post, ...feeds[FeedScope.general]!];
    return post;
  }

  @override
  Future<void> setLike(String postId, {required bool liked}) async {
    likeCalls.add((postId, liked));
    await likeGate?.future;
    final error = likeError;
    if (error != null) throw error;
    _applyLike(postId, liked);
  }

  /// O servidor passa a devolver a curtida nas consultas seguintes (feed e detalhe).
  void _applyLike(String postId, bool liked) {
    Post update(Post p) {
      if (p.id != postId || p.likedByMe == liked) return p;
      return p.copyWith(
        likedByMe: liked,
        likeCount: (p.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 30),
      );
    }

    for (final scope in feeds.keys) {
      feeds[scope] = [for (final p in feeds[scope]!) update(p)];
    }
    posts = {for (final e in posts.entries) e.key: update(e.value)};
  }

  @override
  Future<List<Comment>> comments(String postId) async {
    final error = commentsError;
    if (error != null) throw error;
    return [...?commentTrees[postId]];
  }

  @override
  Future<void> addComment(
    String postId,
    String content, {
    String? parentCommentId,
  }) async {
    await commentGate?.future;
    final error = commentError;
    if (error != null) throw error;
    addedComments.add((
      postId: postId,
      content: content,
      parent: parentCommentId,
    ));
    final comment = fakeComment(
      id: 'n${addedComments.length}',
      postId: postId,
      author: ana,
      content: content,
      parent: parentCommentId,
    );
    final tree = commentTrees[postId] ?? [];
    commentTrees[postId] = parentCommentId == null
        ? [...tree, comment]
        : updateCommentInTree(
            tree,
            parentCommentId,
            (c) => c.copyWith(replies: [...c.replies, comment]),
          );
  }

  @override
  Future<void> setCommentLike(String commentId, {required bool liked}) async {
    commentLikeCalls.add((commentId, liked));
    final error = likeError;
    if (error != null) throw error;
  }
}
