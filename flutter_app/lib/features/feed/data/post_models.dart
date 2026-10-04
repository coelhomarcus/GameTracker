import '../../../core/design_system/game_status.dart';
import '../../../core/models/user_summary.dart';
import '../../games/data/game_models.dart';

enum PostType {
  status('status'),
  review('review'),
  activity('activity');

  const PostType(this.apiValue);
  final String apiValue;

  static PostType fromApi(String value) => PostType.values.firstWhere(
    (t) => t.apiValue == value,
    orElse: () => PostType.status,
  );
}

/// Playthrough ao qual o post está ligado. Pode não existir: apagar o registro não apaga o post.
class PostEntryRef {
  const PostEntryRef({required this.id, required this.platform});

  factory PostEntryRef.fromJson(Map<String, dynamic> json) => PostEntryRef(
    id: json['id'] as String,
    platform: json['platform'] as String? ?? '',
  );

  final String id;
  final String platform;
}

class Post {
  const Post({
    required this.id,
    required this.author,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    this.activityStatus,
    this.game,
    this.entry,
    this.imageUrl,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    author: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
    content: json['content'] as String,
    type: PostType.fromApi(json['type'] as String),
    // Snapshot do status no momento da atividade: nunca o status atual do playthrough.
    activityStatus: json['activityStatus'] == null
        ? null
        : GameStatus.fromApi(json['activityStatus'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    game: json['game'] == null
        ? null
        : Game.fromJson(json['game'] as Map<String, dynamic>),
    entry: json['gameEntry'] == null
        ? null
        : PostEntryRef.fromJson(json['gameEntry'] as Map<String, dynamic>),
    imageUrl: json['imageUrl'] as String?,
    likeCount: json['likeCount'] as int? ?? 0,
    commentCount: json['commentCount'] as int? ?? 0,
    likedByMe: json['likedByMe'] as bool? ?? false,
  );

  final String id;
  final UserSummary author;
  final String content;
  final PostType type;
  final GameStatus? activityStatus;
  final DateTime createdAt;
  final Game? game;
  final PostEntryRef? entry;
  final String? imageUrl;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  bool get isActivity => type == PostType.activity;

  Post copyWith({int? likeCount, int? commentCount, bool? likedByMe}) => Post(
    id: id,
    author: author,
    content: content,
    type: type,
    activityStatus: activityStatus,
    createdAt: createdAt,
    game: game,
    entry: entry,
    imageUrl: imageUrl,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    likedByMe: likedByMe ?? this.likedByMe,
  );
}

/// Página de um feed paginado por cursor opaco.
class PostPage {
  const PostPage({required this.items, required this.nextCursor});

  factory PostPage.fromJson(Map<String, dynamic> json) => PostPage(
    items: (json['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Post.fromJson)
        .toList(),
    nextCursor: json['nextCursor'] as String?,
  );

  final List<Post> items;
  final String? nextCursor;
}

enum FeedScope {
  general('general', 'Geral'),
  following('following', 'Seguindo');

  const FeedScope(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

/// Um comentário com as respostas aninhadas. A árvore vem inteira do servidor.
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.content,
    required this.createdAt,
    required this.likeCount,
    required this.likedByMe,
    required this.replies,
    this.parentCommentId,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String,
    postId: json['postId'] as String,
    author: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    parentCommentId: json['parentCommentId'] as String?,
    likeCount: json['likeCount'] as int? ?? 0,
    likedByMe: json['likedByMe'] as bool? ?? false,
    replies: (json['replies'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Comment.fromJson)
        .toList(),
  );

  final String id;
  final String postId;
  final UserSummary author;
  final String content;
  final DateTime createdAt;
  final String? parentCommentId;
  final int likeCount;
  final bool likedByMe;
  final List<Comment> replies;

  Comment copyWith({int? likeCount, bool? likedByMe, List<Comment>? replies}) =>
      Comment(
        id: id,
        postId: postId,
        author: author,
        content: content,
        createdAt: createdAt,
        parentCommentId: parentCommentId,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        replies: replies ?? this.replies,
      );

  /// Total de comentários na subárvore, contando este.
  int get totalCount => 1 + replies.fold(0, (sum, r) => sum + r.totalCount);
}

/// Aplica [change] ao comentário [id], onde quer que esteja na árvore. O resto é preservado.
List<Comment> updateCommentInTree(
  List<Comment> tree,
  String id,
  Comment Function(Comment) change,
) {
  return [
    for (final c in tree)
      if (c.id == id)
        change(c)
      else if (c.replies.isEmpty)
        c
      else
        c.copyWith(replies: updateCommentInTree(c.replies, id, change)),
  ];
}

Comment? findCommentInTree(List<Comment> tree, String id) {
  for (final c in tree) {
    if (c.id == id) return c;
    final found = findCommentInTree(c.replies, id);
    if (found != null) return found;
  }
  return null;
}

int countComments(List<Comment> tree) =>
    tree.fold(0, (sum, c) => sum + c.totalCount);
