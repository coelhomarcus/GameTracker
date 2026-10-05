import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/dates/relative_time.dart';
import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/page_container.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../../../core/network/error_messages.dart';
import '../../../core/navigation/back_navigation.dart';
import '../application/comments_controller.dart';
import '../application/post_store.dart';
import '../data/post_models.dart';
import 'post_tiles.dart';

/// Limite do recuo visual das respostas (px por nível, até [maxIndentLevels] níveis). Respostas
/// mais fundas ficam no último recuo e dizem a quem respondem; nenhum comentário é escondido e a
/// largura do texto nunca diminui além disso.
const maxIndentLevels = 2;
const _indentPerLevel = 16.0;
const maxCommentLength = 500;

/// Achata a árvore em linhas (comentário, profundidade, comentário respondido), em ordem de
/// leitura. Nada é cortado. O terceiro item é `null` nos comentários de topo.
List<(Comment, int, Comment?)> flattenComments(
  List<Comment> tree, [
  int depth = 0,
  Comment? parent,
]) => [
  for (final c in tree) ...[
    (c, depth, parent),
    ...flattenComments(c.replies, depth + 1, c),
  ],
];

class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  Comment? _replyTo;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _text.text.trim();
    if (_sending || content.isEmpty || content.length > maxCommentLength) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(commentsControllerProvider(widget.postId).notifier)
          .add(content, parentCommentId: _replyTo?.id);
      if (!mounted) return;
      _text.clear();
      setState(() => _replyTo = null);
    } catch (e) {
      // Mantém o texto e o alvo da resposta para tentar de novo.
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _reply(Comment comment) {
    setState(() => _replyTo = comment);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final loader = ref.watch(postLoaderProvider(widget.postId));
    final post = ref.watch(postByIdProvider(widget.postId));

    if (post == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const FallbackBackButton(fallback: '/community'),
          title: const Text('Post'),
        ),
        body: loader.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: describeError(e),
            onRetry: () => ref.invalidate(postLoaderProvider(widget.postId)),
          ),
          data: (_) => const LoadingView(),
        ),
      );
    }

    final comments = ref.watch(commentsControllerProvider(widget.postId));
    return Scaffold(
      appBar: AppBar(
        leading: const FallbackBackButton(fallback: '/community'),
        title: Text(post.isActivity ? 'Atividade' : 'Post'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(postLoaderProvider(widget.postId));
                  ref.invalidate(commentsControllerProvider(widget.postId));
                  try {
                    await ref.read(
                      commentsControllerProvider(widget.postId).future,
                    );
                  } catch (_) {
                    // O erro aparece na seção de comentários.
                  }
                },
                child: LayoutBuilder(
                  builder: (context, box) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: PageContainer.insetsFor(
                      box.maxWidth,
                      PageWidth.reading,
                    ).copyWith(top: 0, bottom: Space.lg),
                    children: [
                      PostTile(postId: post.id),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.lg,
                          Space.lg,
                          Space.lg,
                          Space.sm,
                        ),
                        child: Text(
                          'Comentários (${post.commentCount})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _CommentsSection(
                        postId: post.id,
                        comments: comments,
                        onReply: _reply,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _Composer(
              controller: _text,
              focus: _focus,
              replyTo: _replyTo,
              sending: _sending,
              error: _error,
              onClearReply: () => setState(() => _replyTo = null),
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentsSection extends ConsumerWidget {
  const _CommentsSection({
    required this.postId,
    required this.comments,
    required this.onReply,
  });

  final String postId;
  final AsyncValue<List<Comment>> comments;
  final void Function(Comment comment) onReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return comments.when(
      skipLoadingOnRefresh: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(Space.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: ErrorView(
          message: describeError(e),
          onRetry: () => ref.invalidate(commentsControllerProvider(postId)),
        ),
      ),
      data: (tree) {
        if (tree.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(Space.xl),
            child: Center(
              child: Text('Ainda não há comentários. Seja o primeiro.'),
            ),
          );
        }
        return Column(
          children: [
            for (final (comment, depth, parent) in flattenComments(tree))
              CommentTile(
                key: ValueKey(comment.id),
                comment: comment,
                depth: depth,
                replyingTo: depth > maxIndentLevels ? parent : null,
                onReply: () => onReply(comment),
                onLike: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(commentsControllerProvider(postId).notifier)
                        .toggleLike(comment.id);
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(describeError(e))),
                    );
                  }
                },
              ),
          ],
        );
      },
    );
  }
}

class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.depth,
    required this.onReply,
    required this.onLike,
    this.replyingTo,
  });

  final Comment comment;
  final int depth;

  /// Quem este comentário responde, mostrado só quando a resposta é funda demais para o recuo.
  final Comment? replyingTo;
  final VoidCallback onReply;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final indent =
        (depth > maxIndentLevels ? maxIndentLevels : depth) * _indentPerLevel;
    final author = comment.author;

    return Padding(
      padding: EdgeInsets.fromLTRB(Space.lg + indent, Space.sm, Space.lg, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (depth > 0)
              Container(
                width: 2,
                margin: const EdgeInsets.only(right: Space.md),
                color: scheme.outlineVariant,
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.md,
                children: [
                  UserAvatar(
                    name: author.displayName,
                    url: author.avatarUrl,
                    radius: 16,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: Space.sm,
                          children: [
                            Text(author.displayName, style: text.titleSmall),
                            Text(
                              '@${author.username} · ${formatRelativeTime(comment.createdAt)}',
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                        if (replyingTo != null)
                          Text(
                            'Respondendo a @${replyingTo!.author.username}',
                            style: text.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        Text(comment.content, style: text.bodyMedium),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            LikeButton(
                              liked: comment.likedByMe,
                              count: comment.likeCount,
                              onPressed: onLike,
                              subject: 'comentário de ${author.displayName}',
                            ),
                            TextButton(
                              onPressed: onReply,
                              child: Text(
                                'Responder',
                                semanticsLabel:
                                    'Responder a ${author.displayName}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.replyTo,
    required this.sending,
    required this.error,
    required this.onClearReply,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final Comment? replyTo;
  final bool sending;
  final String? error;
  final VoidCallback onClearReply;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.sm,
          Space.sm,
          Space.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyTo != null)
              Semantics(
                container: true,
                label: 'Respondendo a ${replyTo!.author.displayName}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      replyTo!.author.name == null
                          ? 'Respondendo a @${replyTo!.author.username}'
                          : 'Respondendo a ${replyTo!.author.name} '
                                '(@${replyTo!.author.username})',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      replyTo!.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    // Abaixo do texto: com fonte ampliada não cabe ao lado dele.
                    Tooltip(
                      message: 'Cancelar resposta',
                      child: TextButton(
                        onPressed: onClearReply,
                        child: const Text('Cancelar resposta'),
                      ),
                    ),
                  ],
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Semantics(
                  liveRegion: true,
                  child: Text(error!, style: TextStyle(color: scheme.error)),
                ),
              ),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final length = controller.text.trim().length;
                final canSend =
                    !sending && length > 0 && length <= maxCommentLength;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focus,
                        enabled: !sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: maxCommentLength,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: replyTo == null
                              ? 'Escreva um comentário'
                              : 'Escreva sua resposta',
                          counterText: length > 400
                              ? '$length/$maxCommentLength'
                              : '',
                        ),
                      ),
                    ),
                    sending
                        ? const Padding(
                            padding: EdgeInsets.all(Space.md),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton.filled(
                            tooltip: 'Enviar comentário',
                            icon: const Icon(Icons.send),
                            onPressed: canSend ? onSend : null,
                          ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
