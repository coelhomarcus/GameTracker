import { Ionicons, MaterialCommunityIcons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQuery } from '@tanstack/react-query';
import { useCallback, useEffect, useRef, useState } from 'react';
import { FlatList, Pressable, RefreshControl, StyleSheet, Text, View } from 'react-native';
import * as gameEntriesApi from '../api/gameEntries';
import { GameEntryGridCell } from '../components/GameEntryGridCell';
import { GamePickerModal, type PickedGame } from '../components/GamePickerModal';
import { StatusFilterChips } from '../components/StatusFilterChips';
import { IconButton, ListState, RemoteImage, Screen, StatusBadge } from '../components/ui';
import { useGameEntryMutations } from '../hooks/queries/useGameEntryMutations';
import { confirmAction } from '../lib/alert';
import { getPlatformIcon } from '../lib/platformIcon';
import { qk } from '../lib/queryKeys';
import { getViewMode, setViewMode, type ViewMode } from '../lib/viewPreference';
import type { RootStackParamList } from '../navigation/types';
import { colors, elevation, GRID, icon, opacity, radius, space, type, useGridCellWidth } from '../theme';
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
  const [pickerVisible, setPickerVisible] = useState(false);
  const cellWidth = useGridCellWidth();
  const { setStatus, remove } = useGameEntryMutations();

  function handlePickGame(picked: PickedGame) {
    setPickerVisible(false);
    navigation.navigate('TrackingForm', {
      igdbId: picked.igdbId,
      gameName: picked.name,
      platforms: picked.platforms,
    });
  }

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
        confirmAction({
          title: 'Parabéns! 🎉',
          message: `Quer contar pros seus seguidores que zerou ${entry.game.name}?`,
          confirmLabel: 'Postar',
          cancelLabel: 'Agora não',
          onConfirm: () =>
            navigation.navigate('CreatePost', {
              gameEntryId: entry.id,
              gameName: entry.game.name,
              gameCoverUrl: entry.game.coverUrl,
              prefillContent: `Acabei de zerar ${entry.game.name}! 🎮`,
            }),
        });
      }
    },
    [navigation, setStatus],
  );

  const confirmDelete = useCallback(
    (entry: GameEntry) => {
      confirmAction({
        title: 'Remover',
        message: `Remover "${entry.game.name}" dos seus jogos?`,
        confirmLabel: 'Remover',
        destructive: true,
        onConfirm: () => remove.mutate(entry.id),
      });
    },
    [remove],
  );

  const renderListItem = useCallback(
    ({ item }: { item: GameEntry }) => (
      // Sem accessibilityRole: o card já contém dois botões reais (avançar,
      // remover) e um <button> não pode conter outro — vira <button> aninhado
      // no React Native Web, que o navegador corrige sozinho e quebra a
      // hidratação.
      <Pressable
        style={({ pressed }) => [styles.card, pressed && { opacity: opacity.pressed }]}
        onPress={() => openFocus(item)}
      >
        <RemoteImage uri={item.game.coverUrl} style={styles.listCover} />
        <View style={styles.cardBody}>
          <View style={styles.cardHeader}>
            <Text style={styles.cardTitle} numberOfLines={1}>
              {item.game.name}
            </Text>
            <StatusBadge status={item.status} />
          </View>
          <View style={styles.cardMetaRow}>
            <MaterialCommunityIcons name={getPlatformIcon(item.platform)} size={icon.sm} color={colors.textSecondary} />
            <Text style={styles.cardMeta}>
              {item.platform}
              {item.hoursPlayed ? ` · ${item.hoursPlayed}h` : ''}
              {/* Nota é 0–10: exibir em escala de 5 arredondava 7 pra 8. */}
              {item.rating ? ` · nota ${item.rating}/10` : ''}
            </Text>
          </View>

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
              subtitle: 'Toque no + pra buscar um jogo e começar a trackear',
            }}
          />
        }
      />

      <Pressable
        style={({ pressed }) => [styles.fab, pressed && { opacity: opacity.pressed }]}
        onPress={() => setPickerVisible(true)}
        accessibilityRole="button"
        accessibilityLabel="Buscar jogo pra adicionar"
      >
        <Ionicons name="add" size={icon.hero} color={colors.textOnAccent} />
      </Pressable>

      <GamePickerModal
        visible={pickerVisible}
        onClose={() => setPickerVisible(false)}
        onSelect={handlePickGame}
        title="Buscar jogo"
      />
    </Screen>
  );
}

const FAB_SIZE = 56;

const styles = StyleSheet.create({
  topBar: { flexDirection: 'row', alignItems: 'center' },
  fab: {
    position: 'absolute',
    right: space.xl,
    bottom: space.xl,
    width: FAB_SIZE,
    height: FAB_SIZE,
    borderRadius: radius.pill,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
    ...elevation.raised,
  },
  filtersWrap: { flex: 1 },
  viewToggle: { marginRight: space.md },
  // Folga extra pro FAB não cobrir a última linha.
  list: { gap: space.md, paddingBottom: space.huge + space.xl },
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
  cardMetaRow: { flexDirection: 'row', alignItems: 'center', gap: space.xs },
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
