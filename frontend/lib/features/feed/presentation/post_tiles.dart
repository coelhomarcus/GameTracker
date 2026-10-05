import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/dates/relative_time.dart';
import '../../../core/design_system/game_cover.dart';
import '../../../core/design_system/game_status.dart';
import '../../../core/design_system/status_chip.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../../../core/network/error_messages.dart';
import '../application/post_store.dart';
import '../data/post_models.dart';

/// Botão de curtir com contagem. Resposta imediata, rollback em erro (avisado por SnackBar).
/// Serve posts e comentários: quem usa decide o que acontece ao tocar.
class LikeButton extends StatelessWidget {
  const LikeButton({
    super.key,
    required this.liked,
    required this.count,
    required this.onPressed,
    this.subject = 'post',
  });

  final bool liked;
  final int count;
  final VoidCallback onPressed;
  final String subject;

  @override
  Widget build(BuildContext context) {
    final color = context.domainColors.like;
    return Semantics(
      button: true,
      toggled: liked,
      label: liked
          ? 'Descurtir $subject, $count curtidas'
          : 'Curtir $subject, $count curtidas',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.xs,
            children: [
              const SizedBox(width: Space.sm),
              Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: liked ? color : null,
              ),
              Text('$count'),
              const SizedBox(width: Space.sm),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> toggleLikeWithFeedback(
  BuildContext context,
  WidgetRef ref,
  String postId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(postStoreProvider.notifier).toggleLike(postId);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
  }
}

/// Post de usuário no feed e no detalhe. Com [onTap] nulo (detalhe) não é clicável.
class PostTile extends ConsumerWidget {
  const PostTile({super.key, required this.postId, this.onTap});

  final String postId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(postByIdProvider(postId));
    if (post == null) return const SizedBox.shrink();
    if (post.isActivity) return ActivityTile(post: post, onTap: onTap);
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.md,
          Space.lg,
          Space.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.md,
          children: [
            _AuthorAvatar(post: post),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Byline(post: post),
                  const SizedBox(height: Space.xs),
                  Text(post.content, style: text.bodyLarge),
                  if (post.game != null) ...[
                    const SizedBox(height: Space.md),
                    _GameLink(post: post),
                  ],
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      LikeButton(
                        liked: post.likedByMe,
                        count: post.likeCount,
                        onPressed: () =>
                            toggleLikeWithFeedback(context, ref, post.id),
                      ),
                      const SizedBox(width: Space.sm),
                      _CommentCount(post: post, onTap: onTap),
                    ],
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

/// Atividade automática (começou a jogar, zerou…): linha compacta, com o avatar menor. O status
/// mostrado é o *do momento da atividade* (`activityStatus`), não o status atual do registro, e
/// vem com texto (nunca só cor). Curtidas e comentários continuam à mão.
class ActivityTile extends ConsumerWidget {
  const ActivityTile({super.key, required this.post, this.onTap});

  final Post post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = post.activityStatus;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.sm,
          Space.lg,
          Space.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.md,
          children: [
            _AuthorAvatar(post: post, radius: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: post.author.displayName,
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: ' ${post.content}'),
                      ],
                    ),
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: Space.xs),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (status != null) StatusChip(status),
                      Text(
                        formatRelativeTime(post.createdAt),
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                  if (post.game != null) ...[
                    const SizedBox(height: Space.sm),
                    _GameLink(post: post),
                  ],
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      LikeButton(
                        liked: post.likedByMe,
                        count: post.likeCount,
                        onPressed: () =>
                            toggleLikeWithFeedback(context, ref, post.id),
                      ),
                      const SizedBox(width: Space.sm),
                      _CommentCount(post: post, onTap: onTap),
                    ],
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

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.post, this.radius = 20});
  final Post post;

  /// 20 (avatar de 40) nos posts escritos e 16 (de 32) nas atividades.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Perfil de ${post.author.displayName}',
      // Alvo de toque de 48 dp, qualquer que seja o tamanho do avatar.
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.push('/users/${post.author.id}'),
        child: Padding(
          padding: EdgeInsets.all(24 - radius),
          child: UserAvatar(
            name: post.author.displayName,
            url: post.author.avatarUrl,
            radius: radius,
          ),
        ),
      ),
    );
  }
}

class _Byline extends StatelessWidget {
  const _Byline({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.sm,
      children: [
        Text(post.author.displayName, style: text.titleSmall),
        Text(
          '@${post.author.username} · ${formatRelativeTime(post.createdAt)}',
          style: text.bodySmall,
        ),
      ],
    );
  }
}

class _GameLink extends StatelessWidget {
  const _GameLink({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final game = post.game!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Abrir jogo ${game.name}',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/games/${game.igdbId}'),
          child: Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Row(
              spacing: Space.md,
              children: [
                SizedBox(
                  width: 36,
                  child: GameCover(
                    name: game.name,
                    url: game.coverUrl,
                    radius: 6,
                  ),
                ),
                Expanded(
                  child: Text(
                    game.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                if (post.entry != null && post.entry!.platform.isNotEmpty)
                  Text(
                    post.entry!.platform,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentCount extends StatelessWidget {
  const _CommentCount({required this.post, required this.onTap});
  final Post post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '${post.commentCount} comentários',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.xs,
            children: [
              const SizedBox(width: Space.sm),
              const Icon(Icons.mode_comment_outlined, size: 20),
              Text('${post.commentCount}'),
              const SizedBox(width: Space.sm),
            ],
          ),
        ),
      ),
    );
  }
}
