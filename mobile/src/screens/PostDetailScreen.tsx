import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import {
  FlatList,
  Image,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import * as postsApi from '../api/posts';
import { EmptyState } from '../components/EmptyState';
import { LikeButton } from '../components/LikeButton';
import { LoadingState } from '../components/LoadingState';
import { PostCard } from '../components/PostCard';
import { displayName } from '../lib/displayName';
import { formatRelativeTime } from '../lib/relativeTime';
import type { RootStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';
import { forms } from '../theme/forms';
import { radius } from '../theme/radius';
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

function CommentItem({ comment, depth, onLike, onReply }: CommentItemProps) {
  const [expanded, setExpanded] = useState(false);
  const hasReplies = comment.replies.length > 0;

  return (
    <View style={[styles.comment, depth > 0 && styles.commentNested]}>
      {comment.user.avatarUrl ? (
        <Image source={{ uri: comment.user.avatarUrl }} style={styles.commentAvatarImage} />
      ) : (
        <View style={styles.commentAvatar}>
          <Text style={styles.commentAvatarText}>{displayName(comment.user)[0]?.toUpperCase()}</Text>
        </View>
      )}
      <View style={styles.commentBody}>
        <View style={styles.commentHeader}>
          <Text style={styles.commentAuthor}>{displayName(comment.user)}</Text>
          <Text style={styles.commentHandle}>@{comment.user.username}</Text>
          <Text style={styles.commentTime}>· {formatRelativeTime(comment.createdAt)}</Text>
        </View>
        <Text style={styles.commentText}>{comment.content}</Text>

        <View style={styles.commentActions}>
          <LikeButton liked={comment.likedByMe} count={comment.likeCount} size={15} onPress={() => onLike(comment)} />
          <Pressable style={styles.commentActionButton} onPress={() => onReply(comment)}>
            <Ionicons name="chatbubble-outline" size={14} color={colors.textSecondary} />
            <Text style={styles.commentActionText}>Responder</Text>
          </Pressable>
        </View>

        {hasReplies && (
          <Pressable onPress={() => setExpanded((v) => !v)}>
            <Text style={styles.showReplies}>
              {expanded ? 'Ocultar respostas' : `Ver ${comment.replies.length} resposta${comment.replies.length > 1 ? 's' : ''}`}
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
}

export default function PostDetailScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'PostDetail'>>();
  const { postId } = route.params;
  const queryClient = useQueryClient();
  const [content, setContent] = useState('');
  const [replyTarget, setReplyTarget] = useState<ReplyTarget | null>(null);

  const postQuery = useQuery({
    queryKey: ['post', postId],
    queryFn: () => postsApi.getPost(postId),
  });

  const commentsQuery = useQuery({
    queryKey: ['post-comments', postId],
    queryFn: () => postsApi.listComments(postId),
  });

  const likeMutation = useMutation({
    mutationFn: () =>
      postQuery.data?.likedByMe ? postsApi.unlikePost(postId) : postsApi.likePost(postId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['post', postId] });
      queryClient.invalidateQueries({ queryKey: ['feed'] });
    },
  });

  const commentLikeMutation = useMutation({
    mutationFn: (comment: Comment) => (comment.likedByMe ? postsApi.unlikeComment(comment.id) : postsApi.likeComment(comment.id)),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['post-comments', postId] }),
  });

  const commentMutation = useMutation({
    mutationFn: () => postsApi.addComment(postId, content, replyTarget?.id),
    onSuccess: () => {
      setContent('');
      setReplyTarget(null);
      queryClient.invalidateQueries({ queryKey: ['post-comments', postId] });
      queryClient.invalidateQueries({ queryKey: ['post', postId] });
      queryClient.invalidateQueries({ queryKey: ['feed'] });
    },
  });

  function renderComment({ item }: { item: Comment }) {
    return (
      <CommentItem
        comment={item}
        depth={0}
        onLike={(c) => commentLikeMutation.mutate(c)}
        onReply={(c) => setReplyTarget({ id: c.id, username: c.user.username })}
      />
    );
  }

  return (
    <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <FlatList
        data={commentsQuery.data ?? []}
        keyExtractor={(item) => item.id}
        renderItem={renderComment}
        contentContainerStyle={styles.list}
        ListHeaderComponent={
          <View>
            {postQuery.data ? (
              <PostCard
                post={postQuery.data}
                onPress={() => {}}
                onAuthorPress={() => navigation.navigate('UserProfile', { userId: postQuery.data!.userId })}
                onToggleLike={() => likeMutation.mutate()}
              />
            ) : (
              <LoadingState />
            )}
            <Text style={styles.sectionTitle}>Comentários</Text>
          </View>
        }
        ListEmptyComponent={
          commentsQuery.isLoading ? (
            <LoadingState />
          ) : (
            <EmptyState icon="chatbubble-outline" title="Nenhum comentário ainda" subtitle="Seja o primeiro a comentar" />
          )
        }
      />

      {replyTarget && (
        <View style={styles.replyBanner}>
          <Text style={styles.replyBannerText}>
            Respondendo a <Text style={styles.replyBannerUsername}>@{replyTarget.username}</Text>
          </Text>
          <Pressable onPress={() => setReplyTarget(null)} hitSlop={8}>
            <Ionicons name="close" size={16} color={colors.textSecondary} />
          </Pressable>
        </View>
      )}

      <View style={styles.composer}>
        <TextInput
          style={styles.input}
          placeholder={replyTarget ? `Responder a @${replyTarget.username}...` : 'Adicionar comentário...'}
          placeholderTextColor={colors.textSecondary}
          value={content}
          onChangeText={setContent}
        />
        <Pressable
          style={[styles.sendButton, (!content.trim() || commentMutation.isPending) && styles.sendButtonDisabled]}
          disabled={!content.trim() || commentMutation.isPending}
          onPress={() => commentMutation.mutate()}
        >
          <Ionicons name="arrow-up" size={18} color="#fff" />
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  list: { paddingBottom: 16 },
  sectionTitle: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0.6,
    textTransform: 'uppercase',
    color: colors.textSecondary,
    paddingHorizontal: 16,
    paddingTop: 20,
    paddingBottom: 10,
  },
  comment: { flexDirection: 'row', gap: 10, padding: 16, borderBottomWidth: 1, borderBottomColor: colors.border },
  commentNested: { paddingVertical: 12, paddingLeft: 0, borderBottomWidth: 0, marginLeft: 16, borderLeftWidth: 2, borderLeftColor: colors.border },
  commentAvatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },
  commentAvatarImage: { width: 32, height: 32, borderRadius: 16 },
  commentAvatarText: { color: '#fff', fontWeight: '700', fontSize: 13 },
  commentBody: { flex: 1, gap: 2 },
  commentHeader: { flexDirection: 'row', alignItems: 'baseline', gap: 4, flexWrap: 'wrap' },
  commentAuthor: { fontWeight: '600', color: colors.textPrimary },
  commentHandle: { color: colors.textSecondary, fontSize: 12 },
  commentTime: { color: colors.textSecondary, fontSize: 12 },
  commentText: { color: colors.textPrimary },
  commentActions: { flexDirection: 'row', gap: 16, marginTop: 6 },
  commentActionButton: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  commentActionText: { color: colors.textSecondary, fontSize: 12 },
  showReplies: { color: colors.accent, fontSize: 13, fontWeight: '600', marginTop: 8 },
  replyBanner: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: colors.surface,
  },
  replyBannerText: { color: colors.textSecondary, fontSize: 13 },
  replyBannerUsername: { color: colors.accent, fontWeight: '600' },
  composer: { flexDirection: 'row', gap: 8, padding: 12, alignItems: 'center', borderTopWidth: 1, borderTopColor: colors.border },
  input: { ...forms.inputPill, flex: 1 },
  sendButton: {
    backgroundColor: colors.accent,
    borderRadius: radius.pill,
    width: 40,
    height: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sendButtonDisabled: { opacity: 0.4 },
});
