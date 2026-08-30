import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Alert, FlatList, Pressable, RefreshControl, StyleSheet, Text, View } from 'react-native';
import * as gameEntriesApi from '../api/gameEntries';
import type { RootStackParamList } from '../navigation/types';
import type { GameEntry, GameEntryStatus } from '../types/models';

const FILTERS: { value: GameEntryStatus | 'all'; label: string }[] = [
  { value: 'all', label: 'Todos' },
  { value: 'backlog', label: 'Backlog' },
  { value: 'playing', label: 'Jogando' },
  { value: 'completed', label: 'Completo' },
  { value: 'dropped', label: 'Abandonado' },
];

const NEXT_STATUS: Record<GameEntryStatus, GameEntryStatus> = {
  backlog: 'playing',
  playing: 'completed',
  completed: 'dropped',
  dropped: 'backlog',
};

const STATUS_LABEL: Record<GameEntryStatus, string> = {
  backlog: 'Backlog',
  playing: 'Jogando',
  completed: 'Completo',
  dropped: 'Abandonado',
};

export default function MyGamesScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const [filter, setFilter] = useState<GameEntryStatus | 'all'>('all');
  const queryClient = useQueryClient();

  const query = useQuery({
    queryKey: ['game-entries', filter],
    queryFn: () => gameEntriesApi.listMyGameEntries(filter === 'all' ? undefined : filter),
  });

  function invalidate() {
    queryClient.invalidateQueries({ queryKey: ['game-entries'] });
  }

  async function advanceStatus(entry: GameEntry) {
    const newStatus = NEXT_STATUS[entry.status];
    await gameEntriesApi.updateGameEntry(entry.id, { status: newStatus });
    invalidate();

    if (newStatus === 'completed') {
      Alert.alert('Parabéns! 🎉', `Quer contar pros seus seguidores que zerou ${entry.game.name}?`, [
        { text: 'Agora não', style: 'cancel' },
        {
          text: 'Postar',
          onPress: () =>
            navigation.navigate('CreatePost', {
              gameEntryId: entry.id,
              prefillContent: `Acabei de zerar ${entry.game.name}! 🎮`,
            }),
        },
      ]);
    }
  }

  function confirmDelete(entry: GameEntry) {
    Alert.alert('Remover', `Remover "${entry.game.name}" dos seus jogos?`, [
      { text: 'Cancelar', style: 'cancel' },
      {
        text: 'Remover',
        style: 'destructive',
        onPress: async () => {
          await gameEntriesApi.deleteGameEntry(entry.id);
          invalidate();
        },
      },
    ]);
  }

  function renderItem({ item }: { item: GameEntry }) {
    return (
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Text style={styles.cardTitle}>{item.game.name}</Text>
          <View style={styles.badge}>
            <Text style={styles.badgeText}>{STATUS_LABEL[item.status]}</Text>
          </View>
        </View>
        <Text style={styles.cardMeta}>
          {item.platform}
          {item.hoursPlayed ? ` · ${item.hoursPlayed}h` : ''}
          {item.rating ? ` · nota ${item.rating}` : ''}
        </Text>

        <View style={styles.cardActions}>
          <Pressable style={styles.actionButton} onPress={() => advanceStatus(item)}>
            <Text style={styles.actionText}>Avançar status</Text>
          </Pressable>
          <Pressable style={[styles.actionButton, styles.deleteButton]} onPress={() => confirmDelete(item)}>
            <Text style={[styles.actionText, styles.deleteText]}>Remover</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.filters}>
        {FILTERS.map((f) => (
          <Pressable
            key={f.value}
            style={[styles.filterChip, filter === f.value && styles.filterChipActive]}
            onPress={() => setFilter(f.value)}
          >
            <Text style={[styles.filterText, filter === f.value && styles.filterTextActive]}>{f.label}</Text>
          </Pressable>
        ))}
      </View>

      <FlatList
        data={query.data ?? []}
        keyExtractor={(item) => item.id}
        renderItem={renderItem}
        contentContainerStyle={styles.list}
        refreshControl={<RefreshControl refreshing={query.isFetching} onRefresh={() => query.refetch()} />}
        ListEmptyComponent={!query.isFetching ? <Text style={styles.empty}>Nenhum jogo por aqui ainda</Text> : null}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16 },
  filters: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 12 },
  filterChip: { borderWidth: 1, borderColor: '#ccc', borderRadius: 16, paddingVertical: 6, paddingHorizontal: 12 },
  filterChipActive: { backgroundColor: '#4f46e5', borderColor: '#4f46e5' },
  filterText: { color: '#333', fontSize: 13 },
  filterTextActive: { color: '#fff', fontWeight: '600' },
  list: { gap: 12 },
  card: { borderWidth: 1, borderColor: '#eee', borderRadius: 10, padding: 12, gap: 6 },
  cardHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  cardTitle: { fontSize: 16, fontWeight: '600', flex: 1 },
  badge: { backgroundColor: '#eef2ff', borderRadius: 12, paddingVertical: 3, paddingHorizontal: 8 },
  badgeText: { color: '#4f46e5', fontSize: 12, fontWeight: '600' },
  cardMeta: { color: '#666', fontSize: 13 },
  cardActions: { flexDirection: 'row', gap: 8, marginTop: 4 },
  actionButton: { borderWidth: 1, borderColor: '#ccc', borderRadius: 8, paddingVertical: 6, paddingHorizontal: 10 },
  actionText: { fontSize: 13, color: '#333' },
  deleteButton: { borderColor: '#fecaca' },
  deleteText: { color: '#dc2626' },
  empty: { color: '#666', textAlign: 'center', marginTop: 32 },
});
