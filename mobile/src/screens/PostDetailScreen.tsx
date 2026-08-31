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
import { LoadingState } from '../components/LoadingState';
import { PostCard } from '../components/PostCard';
import { formatRelativeTime } from '../lib/relativeTime';
import type { RootStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';
import type { Comment } from '../types/models';

export default function PostDetailScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'PostDetail'>>();
  const { postId } = route.params;
  const queryClient = useQueryClient();
  const [content, setContent] = useState('');

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

  const commentMutation = useMutation({
    mutationFn: () => postsApi.addComment(postId, content),
    onSuccess: () => {
      setContent('');
      queryClient.invalidateQueries({ queryKey: ['post-comments', postId] });
      queryClient.invalidateQueries({ queryKey: ['post', postId] });
      queryClient.invalidateQueries({ queryKey: ['feed'] });
    },
  });

  function renderComment({ item }: { item: Comment }) {
    return (
      <View style={styles.comment}>
        {item.user.avatarUrl ? (
          <Image source={{ uri: item.user.avatarUrl }} style={styles.commentAvatarImage} />
        ) : (
          <View style={styles.commentAvatar}>
            <Text style={styles.commentAvatarText}>{item.user.username[0]?.toUpperCase()}</Text>
          </View>
        )}
        <View style={styles.commentBody}>
          <View style={styles.commentHeader}>
            <Text style={styles.commentAuthor}>{item.user.username}</Text>
            <Text style={styles.commentTime}>· {formatRelativeTime(item.createdAt)}</Text>
          </View>
          <Text style={styles.commentText}>{item.content}</Text>
        </View>
      </View>
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

      <View style={styles.composer}>
        <TextInput
          style={styles.input}
          placeholder="Adicionar comentário..."
          placeholderTextColor={colors.textSecondary}
          value={content}
          onChangeText={setContent}
        />
        <Pressable
          style={styles.sendButton}
          disabled={!content.trim() || commentMutation.isPending}
          onPress={() => commentMutation.mutate()}
        >
          <Text style={styles.sendButtonText}>Enviar</Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  list: { paddingBottom: 16 },
  sectionTitle: {
    fontSize: 15,
    fontWeight: '700',
    color: colors.textPrimary,
    padding: 16,
    paddingBottom: 8,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  comment: { flexDirection: 'row', gap: 10, padding: 16, borderBottomWidth: 1, borderBottomColor: colors.border },
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
  commentHeader: { flexDirection: 'row', alignItems: 'baseline', gap: 4 },
  commentAuthor: { fontWeight: '600', color: colors.textPrimary },
  commentTime: { color: colors.textSecondary, fontSize: 12 },
  commentText: { color: colors.textPrimary },
  composer: { flexDirection: 'row', gap: 8, padding: 12, borderTopWidth: 1, borderTopColor: colors.border },
  input: { flex: 1, borderWidth: 1, borderColor: colors.border, borderRadius: 8, padding: 10, color: colors.textPrimary },
  sendButton: { backgroundColor: colors.accent, borderRadius: 8, paddingHorizontal: 16, justifyContent: 'center' },
  sendButtonText: { color: '#fff', fontWeight: '600' },
});
