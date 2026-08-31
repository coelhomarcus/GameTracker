import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { memo, useCallback, useState } from 'react';
import { FlatList, Pressable, StyleSheet, Text, View } from 'react-native';
import * as postsApi from '../api/posts';
import { LikeButton } from '../components/LikeButton';
import { LoadingState } from '../components/LoadingState';
import { ActivityRow } from '../components/ActivityRow';
import { PostCard } from '../components/PostCard';
import { Avatar, Composer, ErrorState, IconButton, ListState, Screen } from '../components/ui';
import { useToggleLike } from '../hooks/queries/useToggleLike';
import { getApiErrorMessage } from '../lib/apiError';
import { displayName } from '../lib/displayName';
import { qk } from '../lib/queryKeys';
import { formatRelativeTime } from '../lib/relativeTime';
import type { RootStackParamList } from '../navigation/types';
import { colors, hit, icon, opacity, space, type } from '../theme';
import type { Comment } from '../types/models';

interface ReplyTarget {
  id: string;
  username: string;
}

interface CommentItemProps {
  comment: Comment;
  depth: number;
  onLike: (comment: Comment) => void;
  onReply: (comment: Comment) => void;
}

const CommentItem = memo(function CommentItem({ comment, depth, onLike, onReply }: CommentItemProps) {
  const [expanded, setExpanded] = useState(false);
  const hasReplies = comment.replies.length > 0;

  return (
    <View style={[styles.comment, depth > 0 && styles.commentNested]}>
      <Avatar user={comment.user} size="md" />
      <View style={styles.commentBody}>
        <View style={styles.commentHeader}>
          <Text style={styles.commentAuthor}>{displayName(comment.user)}</Text>
          <Text style={styles.commentHandle}>@{comment.user.username}</Text>
          <Text style={styles.commentTime}>· {formatRelativeTime(comment.createdAt)}</Text>
        </View>
        <Text style={styles.commentText}>{comment.content}</Text>

        <View style={styles.commentActions}>
          <LikeButton liked={comment.likedByMe} count={comment.likeCount} size={icon.sm} onPress={() => onLike(comment)} />
          <Pressable
            style={({ pressed }) => [styles.commentActionButton, pressed && { opacity: opacity.pressed }]}
            onPress={() => onReply(comment)}
            hitSlop={hit.sm}
            accessibilityRole="button"
            accessibilityLabel={`Responder a ${comment.user.username}`}
          >
            <Ionicons name="chatbubble-outline" size={icon.sm} color={colors.textSecondary} />
            <Text style={styles.commentActionText}>Responder</Text>
          </Pressable>
        </View>

        {hasReplies && (
          <Pressable
            onPress={() => setExpanded((value) => !value)}
            hitSlop={hit.sm}
            accessibilityRole="button"
            style={({ pressed }) => pressed && { opacity: opacity.pressed }}
          >
            <Text style={styles.showReplies}>
              {expanded
                ? 'Ocultar respostas'
                : `Ver ${comment.replies.length} resposta${comment.replies.length > 1 ? 's' : ''}`}
            </Text>
          </Pressable>
        )}

        {expanded &&
          comment.replies.map((reply) => (
            <CommentItem key={reply.id} comment={reply} depth={depth + 1} onLike={onLike} onReply={onReply} />
          ))}
      </View>
    </View>
  );
});

export default function PostDetailScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'PostDetail'>>();
  const { postId } = route.params;
  const queryClient = useQueryClient();
  const [content, setContent] = useState('');
  const [replyTarget, setReplyTarget] = useState<ReplyTarget | null>(null);

  const postQuery = useQuery({
    queryKey: qk.post(postId),
    queryFn: () => postsApi.getPost(postId),
  });

  const commentsQuery = useQuery({
    queryKey: qk.postComments(postId),
    queryFn: () => postsApi.listComments(postId),
  });

  const toggleLike = useToggleLike();

  const commentLikeMutation = useMutation({
    mutationFn: (comment: Comment) =>
      comment.likedByMe ? postsApi.unlikeComment(comment.id) : postsApi.likeComment(comment.id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: qk.postComments(postId) }),
  });

  const commentMutation = useMutation({
    mutationFn: () => postsApi.addComment(postId, content.trim(), replyTarget?.id),
    onSuccess: () => {
      setContent('');
      setReplyTarget(null);
      queryClient.invalidateQueries({ queryKey: qk.postComments(postId) });
      queryClient.invalidateQueries({ queryKey: qk.post(postId) });
      queryClient.invalidateQueries({ queryKey: qk.feed() });
    },
  });

  const onLike = useCallback((comment: Comment) => commentLikeMutation.mutate(comment), [commentLikeMutation]);
  const onReply = useCallback(
    (comment: Comment) => setReplyTarget({ id: comment.id, username: comment.user.username }),
    [],
  );

  const renderComment = useCallback(
    ({ item }: { item: Comment }) => <CommentItem comment={item} depth={0} onLike={onLike} onReply={onReply} />,
    [onLike, onReply],
  );

  const PostRow = postQuery.data?.type === 'activity' ? ActivityRow : PostCard;

  return (
    <Screen keyboard>
      <FlatList
        data={commentsQuery.data ?? []}
        keyExtractor={(item) => item.id}
        renderItem={renderComment}
        contentContainerStyle={styles.list}
        keyboardShouldPersistTaps="handled"
        ListHeaderComponent={
          <View>
            {postQuery.isError ? (
              <ErrorState error={postQuery.error} onRetry={() => postQuery.refetch()} />
            ) : postQuery.data ? (
              <PostRow
                post={postQuery.data}
                onPress={() => {}}
                onAuthorPress={() => navigation.navigate('UserProfile', { userId: postQuery.data!.userId })}
                onToggleLike={() => toggleLike.mutate(postQuery.data!)}
              />
            ) : (
              <LoadingState />
            )}
            <Text style={styles.sectionTitle}>Comentários</Text>
          </View>
        }
        ListEmptyComponent={
          <ListState
            query={commentsQuery}
            empty={{
              icon: 'chatbubble-outline',
              title: 'Nenhum comentário ainda',
              subtitle: 'Seja o primeiro a comentar',
            }}
          />
        }
      />

      {commentMutation.isError && (
        <Text style={styles.error}>{getApiErrorMessage(commentMutation.error)}</Text>
      )}

      <Composer
        value={content}
        onChangeText={setContent}
        onSubmit={() => commentMutation.mutate()}
        placeholder={replyTarget ? `Responder a @${replyTarget.username}...` : 'Adicionar comentário...'}
        sending={commentMutation.isPending}
        banner={
          replyTarget ? (
            <View style={styles.replyBanner}>
              <Text style={styles.replyBannerText}>
                Respondendo a <Text style={styles.replyBannerUsername}>@{replyTarget.username}</Text>
              </Text>
              <IconButton
                name="close"
                size="md"
                onPress={() => setReplyTarget(null)}
                accessibilityLabel="Cancelar resposta"
              />
            </View>
          ) : null
        }
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  list: { paddingBottom: space.lg },
  sectionTitle: {
    ...type.eyebrow,
    color: colors.textSecondary,
    paddingHorizontal: space.lg,
    paddingTop: space.xl,
    paddingBottom: space.md,
  },
  comment: {
    flexDirection: 'row',
    gap: space.md,
    padding: space.lg,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  commentNested: {
    paddingVertical: space.md,
    paddingLeft: 0,
    borderBottomWidth: 0,
    marginLeft: space.lg,
    borderLeftWidth: 2,
    borderLeftColor: colors.border,
  },
  commentBody: { flex: 1, gap: space.hair },
  commentHeader: { flexDirection: 'row', alignItems: 'baseline', gap: space.xs, flexWrap: 'wrap' },
  commentAuthor: { ...type.bodyStrong, color: colors.textPrimary },
  commentHandle: { ...type.caption, color: colors.textSecondary },
  commentTime: { ...type.dataSm, color: colors.textSecondary },
  commentText: { ...type.body, color: colors.textPrimary },
  commentActions: { flexDirection: 'row', gap: space.lg, marginTop: space.sm },
  commentActionButton: { flexDirection: 'row', alignItems: 'center', gap: space.xs },
  commentActionText: { ...type.micro, color: colors.textSecondary },
  showReplies: { ...type.label, color: colors.accent, marginTop: space.sm },
  replyBanner: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: space.md,
  },
  replyBannerText: { ...type.caption, color: colors.textSecondary },
  replyBannerUsername: { color: colors.accent },
  error: { ...type.caption, color: colors.danger, paddingHorizontal: space.lg, paddingBottom: space.sm },
});
