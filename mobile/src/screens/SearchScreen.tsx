import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { FlatList, Image, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import * as conversationsApi from '../api/conversations';
import * as gamesApi from '../api/games';
import * as usersApi from '../api/users';
import { EmptyState } from '../components/EmptyState';
import { KeyboardAvoidingScreen } from '../components/KeyboardAvoidingScreen';
import { LoadingState } from '../components/LoadingState';
import { getApiErrorMessage } from '../lib/apiError';
import { displayName } from '../lib/displayName';
import type { RootStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';
import type { IgdbSearchResult, UserSearchResult } from '../types/models';

type SearchTab = 'games' | 'users';

const TABS: { value: SearchTab; label: string }[] = [
  { value: 'games', label: 'Jogos' },
  { value: 'users', label: 'Usuários' },
];

export default function SearchScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<SearchTab>('games');
  const [input, setInput] = useState('');
  const [term, setTerm] = useState('');

  useEffect(() => {
    const timeout = setTimeout(() => setTerm(input.trim()), 400);
    return () => clearTimeout(timeout);
  }, [input]);

  const gamesQuery = useQuery({
    queryKey: ['games', 'search', term],
    queryFn: () => gamesApi.searchGames(term),
    enabled: term.length >= 2,
  });

  const usersQuery = useQuery({
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
      const target = usersQuery.data?.find((u) => u.id === userId);
      navigation.navigate('ChatRoom', {
        conversationId: conversation.id,
        otherUsername: target?.username ?? '',
        otherName: target?.name ?? null,
        otherUserId: userId,
        otherAvatarUrl: target?.avatarUrl ?? null,
      });
    },
  });

  const activeQuery = tab === 'games' ? gamesQuery : usersQuery;

  function renderEmpty() {
    if (term.length < 2) {
      return <EmptyState icon="search-outline" title="Busque jogos ou pessoas" subtitle="Digite pelo menos 2 letras pra começar" />;
    }
    if (activeQuery.isFetching) return <LoadingState />;
    if (activeQuery.isError) {
      return <EmptyState icon="alert-circle-outline" title="Falha na busca" subtitle={getApiErrorMessage(activeQuery.error)} />;
    }
    return tab === 'games' ? (
      <EmptyState icon="game-controller-outline" title="Nenhum jogo encontrado" subtitle="Tente buscar por outro nome" />
    ) : (
      <EmptyState icon="people-outline" title="Nenhum usuário encontrado" subtitle="Tente buscar por outro username" />
    );
  }

  function renderGameItem({ item }: { item: IgdbSearchResult }) {
    return (
      <Pressable style={styles.row} onPress={() => navigation.navigate('GameFocus', { igdbId: item.igdbId })}>
        {item.coverUrl ? (
          <Image source={{ uri: item.coverUrl }} style={styles.cover} />
        ) : (
          <View style={[styles.cover, styles.coverPlaceholder]} />
        )}
        <View style={styles.rowInfo}>
          <Text style={styles.rowTitle}>{item.name}</Text>
          <Text style={styles.rowSubtitle}>{item.platforms.slice(0, 3).join(', ') || 'Plataforma desconhecida'}</Text>
        </View>
      </Pressable>
    );
  }

  function renderUserItem({ item }: { item: UserSearchResult }) {
    return (
      <Pressable style={styles.row} onPress={() => navigation.navigate('UserProfile', { userId: item.id })}>
        {item.avatarUrl ? (
          <Image source={{ uri: item.avatarUrl }} style={styles.avatarImage} />
        ) : (
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>{displayName(item)[0]?.toUpperCase()}</Text>
          </View>
        )}
        <View style={styles.rowInfo}>
          <View style={styles.userHeaderRow}>
            <Text style={styles.rowTitle}>{displayName(item)}</Text>
            <Text style={styles.handle}>@{item.username}</Text>
          </View>
          {item.bio && (
            <Text style={styles.rowSubtitle} numberOfLines={1}>
              {item.bio}
            </Text>
          )}
        </View>
        <Pressable style={styles.iconButton} onPress={() => messageMutation.mutate(item.id)}>
          <Ionicons name="chatbubble-outline" size={20} color={colors.accent} />
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
    <KeyboardAvoidingScreen>
      <View style={styles.container}>
        <View style={styles.searchBar}>
          <TextInput
            style={styles.input}
            placeholder="Buscar"
            placeholderTextColor={colors.textSecondary}
            value={input}
            onChangeText={setInput}
            onSubmitEditing={() => setTerm(input.trim())}
            returnKeyType="search"
            autoCapitalize="none"
          />
          <Pressable style={styles.searchButton} onPress={() => setTerm(input.trim())}>
            <Ionicons name="search" size={20} color="#fff" />
          </Pressable>
        </View>

        <View style={styles.tabs}>
          {TABS.map((t) => (
            <Pressable key={t.value} style={styles.tab} onPress={() => setTab(t.value)}>
              <Text style={[styles.tabText, tab === t.value && styles.tabTextActive]}>{t.label}</Text>
              {tab === t.value && <View style={styles.tabIndicator} />}
            </Pressable>
          ))}
        </View>

        {tab === 'games' ? (
          <FlatList
            data={gamesQuery.data ?? []}
            keyExtractor={(item) => String(item.igdbId)}
            renderItem={renderGameItem}
            contentContainerStyle={styles.list}
            ListEmptyComponent={renderEmpty}
          />
        ) : (
          <FlatList
            data={usersQuery.data ?? []}
            keyExtractor={(item) => item.id}
            renderItem={renderUserItem}
            contentContainerStyle={styles.list}
            ListEmptyComponent={renderEmpty}
          />
        )}
      </View>
    </KeyboardAvoidingScreen>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  searchBar: { flexDirection: 'row', gap: 8, padding: 16, paddingBottom: 12 },
  input: { flex: 1, borderWidth: 1, borderColor: colors.border, borderRadius: 8, padding: 12, fontSize: 16, color: colors.textPrimary },
  searchButton: { backgroundColor: colors.accent, borderRadius: 8, paddingHorizontal: 14, alignItems: 'center', justifyContent: 'center' },
  tabs: { flexDirection: 'row', borderBottomWidth: 1, borderBottomColor: colors.border },
  tab: { flex: 1, alignItems: 'center', paddingVertical: 12 },
  tabText: { color: colors.textSecondary, fontWeight: '600', fontSize: 14 },
  tabTextActive: { color: colors.textPrimary },
  tabIndicator: { position: 'absolute', bottom: 0, height: 2, width: '40%', backgroundColor: colors.accent, borderRadius: 1 },
  list: { padding: 16, gap: 12 },
  row: { flexDirection: 'row', gap: 12, alignItems: 'center' },
  cover: { width: 48, height: 64, borderRadius: 6, backgroundColor: colors.backgroundElevated },
  coverPlaceholder: { alignItems: 'center', justifyContent: 'center' },
  rowInfo: { flex: 1 },
  userHeaderRow: { flexDirection: 'row', alignItems: 'baseline', gap: 4, flexWrap: 'wrap' },
  rowTitle: { fontSize: 16, fontWeight: '600', color: colors.textPrimary },
  handle: { fontSize: 13, color: colors.textSecondary },
  rowSubtitle: { fontSize: 13, color: colors.textSecondary, marginTop: 2 },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: { color: '#fff', fontWeight: '700' },
  avatarImage: { width: 40, height: 40, borderRadius: 20 },
  iconButton: { padding: 6 },
  followButton: { borderWidth: 1, borderColor: colors.accent, borderRadius: 16, paddingVertical: 6, paddingHorizontal: 12 },
  followButtonActive: { backgroundColor: colors.accent },
  followButtonText: { color: colors.accent, fontSize: 12, fontWeight: '600' },
  followButtonTextActive: { color: '#fff' },
});
