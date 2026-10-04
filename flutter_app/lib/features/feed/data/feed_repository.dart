import 'package:dio/dio.dart';

import '../../../core/network/app_exception.dart';
import 'post_models.dart';

abstract interface class FeedRepository {
  Future<PostPage> feed(FeedScope scope, {String? cursor});
  Future<Post> post(String id);

  /// Posts de um perfil, só atividades (`activity`) ou só publicações (`post`).
  Future<PostPage> userPosts(
    String userId, {
    required bool activities,
    String? cursor,
  });

  /// Com `gameEntryId` o backend deriva o jogo (e exige que o registro seja do usuário).
  Future<Post> create({
    required String content,
    String? gameId,
    String? gameEntryId,
  });
  Future<void> setLike(String postId, {required bool liked});
  Future<List<Comment>> comments(String postId);
  Future<void> addComment(
    String postId,
    String content, {
    String? parentCommentId,
  });
  Future<void> setCommentLike(String commentId, {required bool liked});
}

class RemoteFeedRepository implements FeedRepository {
  RemoteFeedRepository(this._dio);
  final Dio _dio;

  static const pageSize = 20;

  @override
  Future<PostPage> feed(FeedScope scope, {String? cursor}) =>
      guardApi(() async {
        // O padrão do servidor é `following`: o escopo é sempre enviado de forma explícita.
        final r = await _dio.get<Map<String, dynamic>>(
          '/feed',
          queryParameters: {
            'scope': scope.apiValue,
            'limit': pageSize,
            'cursor': ?cursor,
          },
        );
        return PostPage.fromJson(r.data!);
      });

  @override
  Future<PostPage> userPosts(
    String userId, {
    required bool activities,
    String? cursor,
  }) => guardApi(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/users/$userId/posts',
      queryParameters: {
        'type': activities ? 'activity' : 'post',
        'limit': pageSize,
        'cursor': ?cursor,
      },
    );
    return PostPage.fromJson(r.data!);
  });

  @override
  Future<Post> post(String id) => guardApi(() async {
    final r = await _dio.get<Map<String, dynamic>>('/posts/$id');
    return Post.fromJson(r.data!);
  });

  @override
  Future<Post> create({
    required String content,
    String? gameId,
    String? gameEntryId,
  }) => guardApi(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/posts',
      data: {
        'content': content,
        // Com registro, o backend deriva o jogo; o gameId só vale sem registro.
        if (gameEntryId != null)
          'gameEntryId': gameEntryId
        else
          'gameId': ?gameId,
      },
    );
    return Post.fromJson(r.data!);
  });

  /// Curtir e descurtir são idempotentes no backend (204 nos dois casos).
  @override
  Future<void> setLike(String postId, {required bool liked}) =>
      guardApi(() async {
        if (liked) {
          await _dio.post<void>('/posts/$postId/like');
        } else {
          await _dio.delete<void>('/posts/$postId/like');
        }
      });

  @override
  Future<List<Comment>> comments(String postId) => guardApi(() async {
    final r = await _dio.get<List<dynamic>>('/posts/$postId/comments');
    return r.data!.cast<Map<String, dynamic>>().map(Comment.fromJson).toList();
  });

  @override
  Future<void> addComment(
    String postId,
    String content, {
    String? parentCommentId,
  }) => guardApi(() async {
    await _dio.post<void>(
      '/posts/$postId/comments',
      data: {'content': content, 'parentCommentId': ?parentCommentId},
    );
  });

  @override
  Future<void> setCommentLike(String commentId, {required bool liked}) =>
      guardApi(() async {
        if (liked) {
          await _dio.post<void>('/comments/$commentId/like');
        } else {
          await _dio.delete<void>('/comments/$commentId/like');
        }
      });
}
