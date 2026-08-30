import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import * as conversationsApi from '../api/conversations';
import * as usersApi from '../api/users';
import { getApiErrorMessage } from '../lib/apiError';
import type { RootStackParamList } from '../navigation/types';
import type { UserSearchResult } from '../types/models';

export default function FindUsersScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const queryClient = useQueryClient();
  const [input, setInput] = useState('');
  const [term, setTerm] = useState('');

  useEffect(() => {
    const timeout = setTimeout(() => setTerm(input.trim()), 400);
    return () => clearTimeout(timeout);
  }, [input]);

  const query = useQuery({
    queryKey: ['users', 'search', term],
    queryFn: () => usersApi.searchUsers(term),
    enabled: term.length >= 2,
  });

  const followMutation = useMutation({
    mutationFn: (user: UserSearchResult) => (user.isFollowedByMe ? usersApi.unfollow(user.id) : usersApi.follow(user.id)),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['users', 'search'] }),
  });

  const messageMutation = useMutation({
    mutationFn: (userId: string) => conversationsApi.createOrGetConversation(userId),
    onSuccess: (conversation, userId) => {
      const target = query.data?.find((u) => u.id === userId);
      navigation.navigate('ChatRoom', {
        conversationId: conversation.id,
        otherUsername: target?.username ?? '',
        otherUserId: userId,
        otherAvatarUrl: target?.avatarUrl ?? null,
      });
    },
  });

  function renderItem({ item }: { item: UserSearchResult }) {
    return (
      <Pressable style={styles.row} onPress={() => navigation.navigate('UserProfile', { userId: item.id })}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>{item.username[0]?.toUpperCase()}</Text>
        </View>
        <View style={styles.rowInfo}>
          <Text style={styles.rowTitle}>{item.username}</Text>
          {item.bio && (
            <Text style={styles.rowSubtitle} numberOfLines={1}>
              {item.bio}
            </Text>
          )}
        </View>
        <Pressable style={styles.iconButton} onPress={() => messageMutation.mutate(item.id)}>
          <Ionicons name="chatbubble-outline" size={20} color="#4f46e5" />
        </Pressable>
        <Pressable
          style={[styles.followButton, item.isFollowedByMe && styles.followButtonActive]}
          onPress={() => followMutation.mutate(item)}
        >
          <Text style={[styles.followButtonText, item.isFollowedByMe && styles.followButtonTextActive]}>
            {item.isFollowedByMe ? 'Seguindo' : 'Seguir'}
          </Text>
        </Pressable>
      </Pressable>
    );
  }

  return (
    <View style={styles.container}>
      <TextInput
        style={styles.input}
        placeholder="Buscar por username..."
        value={input}
        onChangeText={setInput}
        autoCapitalize="none"
      />

      {query.isFetching && <ActivityIndicator style={styles.spinner} />}
      {query.isError && <Text style={styles.error}>{getApiErrorMessage(query.error, 'Falha na busca')}</Text>}
      {term.length >= 2 && !query.isFetching && query.data?.length === 0 && (
        <Text style={styles.empty}>Nenhum usuário encontrado</Text>
      )}

      <FlatList data={query.data ?? []} keyExtractor={(item) => item.id} renderItem={renderItem} contentContainerStyle={styles.list} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16 },
  input: { borderWidth: 1, borderColor: '#ccc', borderRadius: 8, padding: 12, fontSize: 16, marginBottom: 12 },
  spinner: { marginVertical: 8 },
  error: { color: '#dc2626', marginVertical: 8 },
  empty: { color: '#666', marginVertical: 8 },
  list: { gap: 12 },
  row: { flexDirection: 'row', gap: 10, alignItems: 'center' },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#4f46e5',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: { color: '#fff', fontWeight: '700' },
  rowInfo: { flex: 1 },
  rowTitle: { fontSize: 15, fontWeight: '600' },
  rowSubtitle: { fontSize: 13, color: '#666', marginTop: 2 },
  iconButton: { padding: 6 },
  followButton: { borderWidth: 1, borderColor: '#4f46e5', borderRadius: 16, paddingVertical: 6, paddingHorizontal: 12 },
  followButtonActive: { backgroundColor: '#4f46e5' },
  followButtonText: { color: '#4f46e5', fontSize: 12, fontWeight: '600' },
  followButtonTextActive: { color: '#fff' },
});
