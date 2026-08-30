import { useRoute, type RouteProp } from '@react-navigation/native';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { FlatList, KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import * as postsApi from '../api/posts';
import type { RootStackParamList } from '../navigation/types';
import type { Comment } from '../types/models';

export default function PostDetailScreen() {
  const route = useRoute<RouteProp<RootStackParamList, 'PostDetail'>>();
  const { postId } = route.params;
  const queryClient = useQueryClient();
  const [content, setContent] = useState('');

  const commentsQuery = useQuery({
    queryKey: ['post-comments', postId],
    queryFn: () => postsApi.listComments(postId),
  });

  const mutation = useMutation({
    mutationFn: () => postsApi.addComment(postId, content),
    onSuccess: () => {
      setContent('');
      queryClient.invalidateQueries({ queryKey: ['post-comments', postId] });
      queryClient.invalidateQueries({ queryKey: ['feed'] });
    },
  });

  function renderComment({ item }: { item: Comment }) {
    return (
      <View style={styles.comment}>
        <Text style={styles.commentAuthor}>{item.user.username}</Text>
        <Text>{item.content}</Text>
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
        ListEmptyComponent={!commentsQuery.isLoading ? <Text style={styles.empty}>Nenhum comentário ainda</Text> : null}
      />

      <View style={styles.composer}>
        <TextInput
          style={styles.input}
          placeholder="Adicionar comentário..."
          value={content}
          onChangeText={setContent}
        />
        <Pressable
          style={styles.sendButton}
          disabled={!content.trim() || mutation.isPending}
          onPress={() => mutation.mutate()}
        >
          <Text style={styles.sendButtonText}>Enviar</Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  list: { padding: 16, gap: 12 },
  comment: { borderBottomWidth: 1, borderBottomColor: '#eee', paddingBottom: 8 },
  commentAuthor: { fontWeight: '600', marginBottom: 2 },
  empty: { color: '#666', textAlign: 'center', marginTop: 32 },
  composer: { flexDirection: 'row', gap: 8, padding: 12, borderTopWidth: 1, borderTopColor: '#eee' },
  input: { flex: 1, borderWidth: 1, borderColor: '#ccc', borderRadius: 8, padding: 10 },
  sendButton: { backgroundColor: '#4f46e5', borderRadius: 8, paddingHorizontal: 16, justifyContent: 'center' },
  sendButtonText: { color: '#fff', fontWeight: '600' },
});
