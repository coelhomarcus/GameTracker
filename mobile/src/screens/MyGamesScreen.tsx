import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import {
  Alert,
  FlatList,
  Image,
  Pressable,
  RefreshControl,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from 'react-native';
import * as gameEntriesApi from '../api/gameEntries';
import { EmptyState } from '../components/EmptyState';
import { STATUS_LABEL } from '../lib/gameEntryLabels';
import { getViewMode, setViewMode, type ViewMode } from '../lib/viewPreference';
import type { RootStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';
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

const STATUS_COLOR: Record<GameEntryStatus, string> = {
  backlog: colors.textSecondary,
  playing: colors.accent,
  completed: colors.success,
  dropped: colors.like,
};

const GRID_COLUMNS = 4;
const GRID_GAP = 8;
const CONTAINER_PADDING = 16;

export default function MyGamesScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const [filter, setFilter] = useState<GameEntryStatus | 'all'>('all');
  const [viewMode, setViewModeState] = useState<ViewMode>('grid');
  const queryClient = useQueryClient();
  const { width } = useWindowDimensions();
  const cellWidth = (width - CONTAINER_PADDING * 2 - GRID_GAP * (GRID_COLUMNS - 1)) / GRID_COLUMNS;

  useEffect(() => {
    getViewMode().then(setViewModeState);
  }, []);

  function toggleViewMode() {
    const next: ViewMode = viewMode === 'list' ? 'grid' : 'list';
    setViewModeState(next);
    setViewMode(next);
  }

  const query = useQuery({
    queryKey: ['game-entries', filter],
    queryFn: () => gameEntriesApi.listMyGameEntries({ status: filter === 'all' ? undefined : filter }),
  });

  function invalidate() {
    queryClient.invalidateQueries({ queryKey: ['game-entries'] });
  }

  function openFocus(entry: GameEntry) {
    navigation.navigate('GameFocus', { igdbId: entry.game.igdbId });
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

  function renderListItem({ item }: { item: GameEntry }) {
    return (
      <Pressable style={styles.card} onPress={() => openFocus(item)}>
        {item.game.coverUrl ? (
          <Image source={{ uri: item.game.coverUrl }} style={styles.listCover} />
        ) : (
          <View style={[styles.listCover, styles.coverPlaceholder]} />
        )}
        <View style={styles.cardBody}>
          <View style={styles.cardHeader}>
            <Text style={styles.cardTitle} numberOfLines={1}>
              {item.game.name}
            </Text>
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{STATUS_LABEL[item.status]}</Text>
            </View>
          </View>
          <Text style={styles.cardMeta}>
            {item.platform}
            {item.hoursPlayed ? ` · ${item.hoursPlayed}h` : ''}
            {item.rating ? ` · nota ${Math.round(item.rating / 2)}/5` : ''}
          </Text>

          <View style={styles.cardActions}>
            <Pressable style={styles.actionButton} onPress={() => advanceStatus(item)}>
              <Ionicons name="arrow-forward-circle-outline" size={16} color={colors.textPrimary} />
              <Text style={styles.actionText}>Avançar</Text>
            </Pressable>
            <Pressable style={[styles.actionButton, styles.deleteButton]} onPress={() => confirmDelete(item)}>
              <Ionicons name="trash-outline" size={16} color={colors.like} />
              <Text style={[styles.actionText, styles.deleteText]}>Remover</Text>
            </Pressable>
          </View>
        </View>
      </Pressable>
    );
  }

  function renderGridItem({ item }: { item: GameEntry }) {
    const coverHeight = cellWidth * (4 / 3);
    return (
      <Pressable style={[styles.gridCard, { width: cellWidth }]} onPress={() => openFocus(item)}>
        <View>
          {item.game.coverUrl ? (
            <Image
              source={{ uri: item.game.coverUrl }}
              style={[styles.gridCover, { width: cellWidth, height: coverHeight }]}
            />
          ) : (
            <View style={[styles.gridCover, styles.coverPlaceholder, { width: cellWidth, height: coverHeight }]} />
          )}
          <View style={[styles.gridStatusDot, { backgroundColor: STATUS_COLOR[item.status] }]} />
        </View>
        <Text style={styles.gridTitle} numberOfLines={1}>
          {item.game.name}
        </Text>
      </Pressable>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.topBar}>
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
        <Pressable style={styles.viewToggle} onPress={toggleViewMode}>
          <Ionicons name={viewMode === 'list' ? 'grid-outline' : 'list-outline'} size={20} color={colors.accent} />
        </Pressable>
      </View>

      <FlatList
        key={viewMode}
        data={query.data ?? []}
        keyExtractor={(item) => item.id}
        renderItem={viewMode === 'list' ? renderListItem : renderGridItem}
        numColumns={viewMode === 'grid' ? GRID_COLUMNS : 1}
        columnWrapperStyle={viewMode === 'grid' ? styles.gridRow : undefined}
        contentContainerStyle={styles.list}
        refreshControl={<RefreshControl refreshing={query.isFetching} onRefresh={() => query.refetch()} />}
        ListEmptyComponent={
          !query.isFetching ? (
            <EmptyState
              icon="game-controller-outline"
              title={filter === 'all' ? 'Nenhum jogo por aqui ainda' : 'Nenhum jogo nesse status'}
              subtitle="Busque um jogo na aba de Busca pra começar a trackear"
            />
          ) : null
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16, backgroundColor: colors.background },
  topBar: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 12 },
  filters: { flex: 1, flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  filterChip: { borderWidth: 1, borderColor: colors.border, borderRadius: 16, paddingVertical: 6, paddingHorizontal: 12 },
  filterChipActive: { backgroundColor: colors.accent, borderColor: colors.accent },
  filterText: { color: colors.textPrimary, fontSize: 13 },
  filterTextActive: { color: '#fff', fontWeight: '600' },
  viewToggle: { borderWidth: 1, borderColor: colors.border, borderRadius: 8, padding: 8 },
  list: { gap: 12 },
  coverPlaceholder: { backgroundColor: colors.backgroundElevated },

  // list mode
  card: { flexDirection: 'row', borderWidth: 1, borderColor: colors.border, borderRadius: 10, padding: 12, gap: 10 },
  listCover: { width: 56, height: 74, borderRadius: 6 },
  cardBody: { flex: 1, gap: 6 },
  cardHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 8 },
  cardTitle: { fontSize: 16, fontWeight: '600', flex: 1, color: colors.textPrimary },
  badge: { backgroundColor: colors.backgroundElevated, borderRadius: 12, paddingVertical: 3, paddingHorizontal: 8 },
  badgeText: { color: colors.accent, fontSize: 12, fontWeight: '600' },
  cardMeta: { color: colors.textSecondary, fontSize: 13 },
  cardActions: { flexDirection: 'row', gap: 8, marginTop: 4 },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 8,
    paddingVertical: 6,
    paddingHorizontal: 10,
  },
  actionText: { fontSize: 13, color: colors.textPrimary },
  deleteButton: { borderColor: colors.like },
  deleteText: { color: colors.like },

  // grid mode
  gridRow: { gap: GRID_GAP, marginBottom: GRID_GAP },
  gridCard: { gap: 4 },
  gridCover: { borderRadius: 6 },
  gridStatusDot: {
    position: 'absolute',
    top: 4,
    right: 4,
    width: 8,
    height: 8,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: colors.background,
  },
  gridTitle: { fontSize: 10, color: colors.textPrimary },
});
