import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQuery } from '@tanstack/react-query';
import { useCallback, useEffect, useState } from 'react';
import { FlatList, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import * as gamesApi from '../api/games';
import * as usersApi from '../api/users';
import { EmptyState } from '../components/EmptyState';
import {
  Avatar,
  Button,
  IconButton,
  ListState,
  RemoteImage,
  Screen,
  SegmentedTabs,
  type Tab,
} from '../components/ui';
import { useFollow } from '../hooks/queries/useFollow';
import { useOpenConversation } from '../hooks/queries/useOpenConversation';
import { displayName } from '../lib/displayName';
import { qk } from '../lib/queryKeys';
import type { RootStackParamList } from '../navigation/types';
import { colors, forms, opacity, radius, space, type } from '../theme';
import type { IgdbSearchResult, UserSearchResult } from '../types/models';

type SearchTab = 'games' | 'users';

const TABS: readonly Tab<SearchTab>[] = [
  { value: 'games', label: 'Jogos' },
  { value: 'users', label: 'Usuários' },
];

const MIN_TERM = 2;

export default function SearchScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const [tab, setTab] = useState<SearchTab>('games');
  const [input, setInput] = useState('');
  const [term, setTerm] = useState('');

  useEffect(() => {
    const timeout = setTimeout(() => setTerm(input.trim()), 400);
    return () => clearTimeout(timeout);
  }, [input]);

  const ready = term.length >= MIN_TERM;

  // Só a aba visível busca: antes as duas queries disparavam a cada termo e
  // uma das duas requisições era sempre desperdiçada.
  const gamesQuery = useQuery({
    queryKey: qk.gamesSearch(term),
    queryFn: () => gamesApi.searchGames(term),
    enabled: ready && tab === 'games',
  });

  const usersQuery = useQuery({
    queryKey: qk.usersSearch(term),
    queryFn: () => usersApi.searchUsers(term),
    enabled: ready && tab === 'users',
  });

  const follow = useFollow();
  const openConversation = useOpenConversation();

  const renderGameItem = useCallback(
    ({ item }: { item: IgdbSearchResult }) => (
      <Pressable
        style={({ pressed }) => [styles.row, pressed && { opacity: opacity.pressed }]}
        onPress={() => navigation.navigate('GameFocus', { igdbId: item.igdbId })}
        accessibilityRole="button"
        accessibilityLabel={item.name}
      >
        <RemoteImage uri={item.coverUrl} style={styles.cover} />
        <View style={styles.rowInfo}>
          <Text style={styles.rowTitle}>{item.name}</Text>
          <Text style={styles.rowSubtitle}>
            {item.platforms.slice(0, 3).join(', ') || 'Plataforma desconhecida'}
          </Text>
        </View>
      </Pressable>
    ),
    [navigation],
  );

  const renderUserItem = useCallback(
    ({ item }: { item: UserSearchResult }) => (
      <Pressable
        style={({ pressed }) => [styles.row, pressed && { opacity: opacity.pressed }]}
        onPress={() => navigation.navigate('UserProfile', { userId: item.id })}
        accessibilityRole="button"
        accessibilityLabel={`Perfil de ${displayName(item)}`}
      >
        <Avatar user={item} size="lg" />
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
        <IconButton
          name="chatbubble-outline"
          color={colors.accent}
          onPress={() => openConversation.mutate(item)}
          accessibilityLabel={`Conversar com ${item.username}`}
        />
        <Button
          label={item.isFollowedByMe ? 'Seguindo' : 'Seguir'}
          variant={item.isFollowedByMe ? 'secondary' : 'primary'}
          size="sm"
          onPress={() => follow.mutate({ userId: item.id, following: item.isFollowedByMe })}
        />
      </Pressable>
    ),
    [navigation, follow, openConversation],
  );

  const activeQuery = tab === 'games' ? gamesQuery : usersQuery;

  const emptyComponent = !ready ? (
    <EmptyState
      icon="search-outline"
      title="Busque jogos ou pessoas"
      subtitle={`Digite pelo menos ${MIN_TERM} letras pra começar`}
    />
  ) : (
    <ListState
      query={activeQuery}
      empty={
        tab === 'games'
          ? {
              icon: 'game-controller-outline',
              title: 'Nenhum jogo encontrado',
              subtitle: 'Tente buscar por outro nome',
            }
          : {
              icon: 'people-outline',
              title: 'Nenhum usuário encontrado',
              subtitle: 'Tente buscar por outro username',
            }
      }
    />
  );

  return (
    <Screen keyboard>
      <View style={styles.searchBar}>
        <TextInput
          style={styles.input}
          placeholder="Buscar"
          placeholderTextColor={colors.textTertiary}
          value={input}
          onChangeText={setInput}
          onSubmitEditing={() => setTerm(input.trim())}
          returnKeyType="search"
          autoCapitalize="none"
          autoCorrect={false}
          accessibilityLabel="Buscar jogos ou pessoas"
        />
        <IconButton
          name="search"
          variant="filled"
          onPress={() => setTerm(input.trim())}
          accessibilityLabel="Buscar"
          style={styles.searchButton}
        />
      </View>

      <SegmentedTabs tabs={TABS} value={tab} onChange={setTab} />

      {tab === 'games' ? (
        <FlatList
          data={gamesQuery.data ?? []}
          keyExtractor={(item) => String(item.igdbId)}
          renderItem={renderGameItem}
          contentContainerStyle={styles.list}
          // Sem isto o primeiro toque num resultado só fechava o teclado.
          keyboardShouldPersistTaps="handled"
          ListEmptyComponent={emptyComponent}
        />
      ) : (
        <FlatList
          data={usersQuery.data ?? []}
          keyExtractor={(item) => item.id}
          renderItem={renderUserItem}
          contentContainerStyle={styles.list}
          keyboardShouldPersistTaps="handled"
          ListEmptyComponent={emptyComponent}
        />
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  searchBar: { flexDirection: 'row', gap: space.sm, padding: space.lg, paddingBottom: space.md },
  input: { ...forms.inputPill, flex: 1, paddingVertical: space.md },
  searchButton: { paddingHorizontal: space.md },
  list: { padding: space.lg, gap: space.md },
  row: { flexDirection: 'row', gap: space.md, alignItems: 'center' },
  cover: { width: 48, height: 64, borderRadius: radius.sm, backgroundColor: colors.skeleton },
  rowInfo: { flex: 1 },
  userHeaderRow: { flexDirection: 'row', alignItems: 'baseline', gap: space.xs, flexWrap: 'wrap' },
  rowTitle: { ...type.bodyLg, fontFamily: type.bodyStrong.fontFamily, color: colors.textPrimary },
  handle: { ...type.caption, color: colors.textSecondary },
  rowSubtitle: { ...type.caption, color: colors.textSecondary, marginTop: space.hair },
});
