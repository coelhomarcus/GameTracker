import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQuery } from '@tanstack/react-query';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Alert, FlatList, Pressable, RefreshControl, StyleSheet, Text, View } from 'react-native';
import * as gameEntriesApi from '../api/gameEntries';
import { GameEntryGridCell } from '../components/GameEntryGridCell';
import { StatusFilterChips } from '../components/StatusFilterChips';
import { IconButton, ListState, RemoteImage, Screen, StatusBadge } from '../components/ui';
import { useGameEntryMutations } from '../hooks/queries/useGameEntryMutations';
import { qk } from '../lib/queryKeys';
import { getViewMode, setViewMode, type ViewMode } from '../lib/viewPreference';
import type { RootStackParamList } from '../navigation/types';
import { colors, GRID, icon, opacity, radius, space, type, useGridCellWidth } from '../theme';
import type { GameEntry, GameEntryStatus } from '../types/models';

const NEXT_STATUS: Record<GameEntryStatus, GameEntryStatus> = {
  backlog: 'playing',
  playing: 'completed',
  completed: 'dropped',
  dropped: 'backlog',
};

export default function MyGamesScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const [filter, setFilter] = useState<GameEntryStatus | 'all'>('all');
  const [viewMode, setViewModeState] = useState<ViewMode>('grid');
  const cellWidth = useGridCellWidth();
  const { setStatus, remove } = useGameEntryMutations();

  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    getViewMode().then((mode) => {
      if (mounted.current) setViewModeState(mode);
    });
    return () => {
      mounted.current = false;
    };
  }, []);

  function toggleViewMode() {
    const next: ViewMode = viewMode === 'list' ? 'grid' : 'list';
    setViewModeState(next);
    setViewMode(next);
  }

  const query = useQuery({
    queryKey: qk.gameEntriesFiltered(filter),
    queryFn: () => gameEntriesApi.listMyGameEntries({ status: filter === 'all' ? undefined : filter }),
  });

  const openFocus = useCallback(
    (entry: GameEntry) => navigation.navigate('GameFocus', { igdbId: entry.game.igdbId }),
    [navigation],
  );

  const advanceStatus = useCallback(
    (entry: GameEntry) => {
      const next = NEXT_STATUS[entry.status];
      setStatus.mutate({ entry, status: next });

      if (next === 'completed') {
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
    },
    [navigation, setStatus],
  );

  const confirmDelete = useCallback(
    (entry: GameEntry) => {
      Alert.alert('Remover', `Remover "${entry.game.name}" dos seus jogos?`, [
        { text: 'Cancelar', style: 'cancel' },
        { text: 'Remover', style: 'destructive', onPress: () => remove.mutate(entry.id) },
      ]);
    },
    [remove],
  );

  const renderListItem = useCallback(
    ({ item }: { item: GameEntry }) => (
      <Pressable
        style={({ pressed }) => [styles.card, pressed && { opacity: opacity.pressed }]}
        onPress={() => openFocus(item)}
        accessibilityRole="button"
        accessibilityLabel={item.game.name}
      >
        <RemoteImage uri={item.game.coverUrl} style={styles.listCover} />
        <View style={styles.cardBody}>
          <View style={styles.cardHeader}>
            <Text style={styles.cardTitle} numberOfLines={1}>
              {item.game.name}
            </Text>
            <StatusBadge status={item.status} />
          </View>
          <Text style={styles.cardMeta}>
            {item.platform}
            {item.hoursPlayed ? ` · ${item.hoursPlayed}h` : ''}
            {/* Nota é 0–10: exibir em escala de 5 arredondava 7 pra 8. */}
            {item.rating ? ` · nota ${item.rating}/10` : ''}
          </Text>

          <View style={styles.cardActions}>
            <Pressable
              style={({ pressed }) => [styles.actionButton, pressed && { opacity: opacity.pressed }]}
              onPress={() => advanceStatus(item)}
              accessibilityRole="button"
              accessibilityLabel={`Avançar status de ${item.game.name}`}
            >
              <Ionicons name="arrow-forward-circle-outline" size={icon.md} color={colors.textPrimary} />
              <Text style={styles.actionText}>Avançar</Text>
            </Pressable>
            <Pressable
              style={({ pressed }) => [styles.actionButton, pressed && { opacity: opacity.pressed }]}
              onPress={() => confirmDelete(item)}
              accessibilityRole="button"
              accessibilityLabel={`Remover ${item.game.name}`}
            >
              <Ionicons name="trash-outline" size={icon.md} color={colors.danger} />
              <Text style={[styles.actionText, styles.deleteText]}>Remover</Text>
            </Pressable>
          </View>
        </View>
      </Pressable>
    ),
    [advanceStatus, confirmDelete, openFocus],
  );

  const renderGridItem = useCallback(
    ({ item }: { item: GameEntry }) => (
      <GameEntryGridCell entry={item} width={cellWidth} onPress={() => openFocus(item)} />
    ),
    [cellWidth, openFocus],
  );

  return (
    <Screen>
      <View style={styles.topBar}>
        <View style={styles.filtersWrap}>
          <StatusFilterChips value={filter} onChange={setFilter} />
        </View>
        <IconButton
          name={viewMode === 'list' ? 'grid-outline' : 'list-outline'}
          onPress={toggleViewMode}
          accessibilityLabel={viewMode === 'list' ? 'Ver em grade' : 'Ver em lista'}
          style={styles.viewToggle}
        />
      </View>

      <FlatList
        key={viewMode}
        data={query.data ?? []}
        keyExtractor={(item) => item.id}
        renderItem={viewMode === 'list' ? renderListItem : renderGridItem}
        numColumns={viewMode === 'grid' ? GRID.columns : 1}
        columnWrapperStyle={viewMode === 'grid' ? styles.gridRow : undefined}
        contentContainerStyle={[styles.list, viewMode === 'list' && styles.listPadded]}
        keyboardShouldPersistTaps="handled"
        // isRefetching, não isFetching: com isFetching o estado de carregando
        // nunca renderizava e o spinner de refresh aparecia na montagem.
        refreshControl={<RefreshControl refreshing={query.isRefetching} onRefresh={() => query.refetch()} />}
        ListEmptyComponent={
          <ListState
            query={query}
            empty={{
              icon: 'game-controller-outline',
              title: filter === 'all' ? 'Nenhum jogo por aqui ainda' : 'Nenhum jogo nesse status',
              subtitle: 'Busque um jogo na aba de Busca pra começar a trackear',
            }}
          />
        }
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  topBar: { flexDirection: 'row', alignItems: 'center' },
  filtersWrap: { flex: 1 },
  viewToggle: { marginRight: space.md },
  list: { gap: space.md, paddingBottom: space.xl },
  listPadded: { paddingHorizontal: space.lg },

  // modo lista
  card: {
    flexDirection: 'row',
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    padding: space.md,
    gap: space.md,
  },
  listCover: { width: 56, height: 74, borderRadius: radius.sm, backgroundColor: colors.skeleton },
  cardBody: { flex: 1, gap: space.sm },
  cardHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: space.sm },
  cardTitle: { ...type.bodyLg, fontFamily: type.bodyStrong.fontFamily, flex: 1, color: colors.textPrimary },
  // Plataforma, horas e nota são dado de ficha: mono.
  cardMeta: { ...type.data, color: colors.textSecondary },
  cardActions: { flexDirection: 'row', gap: space.sm, marginTop: space.xs },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: space.xs,
    backgroundColor: colors.background,
    borderRadius: radius.pill,
    paddingVertical: space.sm,
    paddingHorizontal: space.md,
  },
  actionText: { ...type.label, color: colors.textSecondary },
  deleteText: { color: colors.danger },

  // modo grade
  gridRow: { gap: GRID.gap, marginBottom: GRID.gap, paddingHorizontal: GRID.padding },
});
