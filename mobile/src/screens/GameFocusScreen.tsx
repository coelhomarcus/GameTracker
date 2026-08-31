import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQuery } from '@tanstack/react-query';
import { useCallback, useState } from 'react';
import { FlatList, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import * as gameEntriesApi from '../api/gameEntries';
import * as gamesApi from '../api/games';
import { ActivityRow } from '../components/ActivityRow';
import { EmptyState } from '../components/EmptyState';
import { ImageViewerModal } from '../components/ImageViewerModal';
import { LoadingState } from '../components/LoadingState';
import { PostCard } from '../components/PostCard';
import { Avatar, Button, ErrorState, ExpandableText, ListFooter, ListState, RemoteImage, Screen, StatusBadge } from '../components/ui';
import { useGamePlayers, useGamePosts, useGameStats } from '../hooks/queries/useGameSocial';
import { useToggleLike } from '../hooks/queries/useToggleLike';
import { displayName } from '../lib/displayName';
import { getPlatformIcon } from '../lib/platformIcon';
import type { RootStackParamList } from '../navigation/types';
import { colors, icon, opacity, radius, space, type } from '../theme';
import type { GameEntry, GamePlayerEntry, Post } from '../types/models';

export default function GameFocusScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'GameFocus'>>();
  const { igdbId } = route.params;
  const [viewerIndex, setViewerIndex] = useState<number | null>(null);

  const gameQuery = useQuery({
    queryKey: ['game-focus', igdbId],
    queryFn: () => gamesApi.getGameByIgdb(igdbId),
  });

  const entriesQuery = useQuery({
    queryKey: ['game-entries', 'igdb', igdbId],
    queryFn: () => gameEntriesApi.listMyGameEntries({ igdbId }),
  });

  // Chamados sempre (regra dos hooks) mas só habilitados depois que o jogo
  // carrega — gameQuery.data pode ainda não existir no primeiro render.
  const gameId = gameQuery.data?.id ?? '';
  const hasGame = !!gameQuery.data;
  const statsQuery = useGameStats(gameId, hasGame);
  const playingQuery = useGamePlayers(gameId, 'playing', 'all', hasGame);
  const friendsQuery = useGamePlayers(gameId, 'playing', 'following', hasGame);
  const gamePosts = useGamePosts(gameId, hasGame);
  const toggleLike = useToggleLike();

  const renderPost = useCallback(
    ({ item }: { item: Post }) => {
      const Row = item.type === 'activity' ? ActivityRow : PostCard;
      return (
        <Row
          post={item}
          onPress={() => navigation.navigate('PostDetail', { postId: item.id })}
          onAuthorPress={() => navigation.navigate('UserProfile', { userId: item.userId })}
          onToggleLike={() => toggleLike.mutate(item)}
        />
      );
    },
    [navigation, toggleLike],
  );

  if (gameQuery.isLoading) return <LoadingState fullScreen />;

  // Antes isto era `isLoading || !data`: num erro de rede, isLoading vira false
  // e data fica undefined, então a tela girava pra sempre sem oferecer retry.
  if (gameQuery.isError || !gameQuery.data) {
    return (
      <Screen>
        <ErrorState error={gameQuery.error} onRetry={() => gameQuery.refetch()} />
      </Screen>
    );
  }

  const game = gameQuery.data;

  function openForm(entry?: GameEntry) {
    navigation.navigate('TrackingForm', {
      igdbId,
      gameName: game.name,
      platforms: game.platforms,
      entryId: entry?.id,
      initial: entry
        ? {
            platform: entry.platform,
            status: entry.status,
            startedAt: entry.startedAt,
            finishedAt: entry.finishedAt,
            hoursPlayed: entry.hoursPlayed,
            rating: entry.rating,
            notes: entry.notes,
          }
        : undefined,
    });
  }

  function openPlayer(player: GamePlayerEntry) {
    navigation.navigate('UserProfile', { userId: player.user.id });
  }

  function renderPlayersRow(title: string, players: GamePlayerEntry[] | undefined) {
    if (!players || players.length === 0) return null;
    return (
      <View>
        <Text style={styles.sectionTitle}>{title}</Text>
        <View style={styles.playersRow}>
          {players.map((player) => (
            <Pressable
              key={player.user.id}
              style={({ pressed }) => [styles.playerItem, pressed && { opacity: opacity.pressed }]}
              onPress={() => openPlayer(player)}
              accessibilityRole="button"
              accessibilityLabel={displayName(player.user)}
            >
              <Avatar user={player.user} size="lg" />
              <Text style={styles.playerName} numberOfLines={1}>
                {displayName(player.user)}
              </Text>
            </Pressable>
          ))}
        </View>
      </View>
    );
  }

  const header = (
    <View>
      <RemoteImage uri={game.coverUrl} style={styles.cover} accessibilityLabel={`Capa de ${game.name}`} />
      <Text style={styles.title}>{game.name}</Text>
      {game.genres.length > 0 && <Text style={styles.subtitle}>{game.genres.join(', ')}</Text>}
      {game.platforms.length > 0 && <Text style={styles.platforms}>{game.platforms.slice(0, 5).join(' · ')}</Text>}
      {game.summary && <ExpandableText text={game.summary} style={styles.summary} />}

      {game.screenshots.length > 0 && (
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={styles.screenshots}
          contentContainerStyle={styles.screenshotsContent}
        >
          {game.screenshots.map((url, index) => (
            <Pressable
              key={url}
              onPress={() => setViewerIndex(index)}
              accessibilityRole="button"
              accessibilityLabel={`Screenshot ${index + 1}`}
              style={({ pressed }) => pressed && { opacity: opacity.pressed }}
            >
              <RemoteImage uri={url} style={styles.screenshot} />
            </Pressable>
          ))}
        </ScrollView>
      )}

      <ImageViewerModal
        visible={viewerIndex !== null}
        images={game.screenshots}
        initialIndex={viewerIndex ?? 0}
        onClose={() => setViewerIndex(null)}
      />

      {statsQuery.data && (
        <Text style={styles.stats}>
          {statsQuery.data.playing} jogando · {statsQuery.data.completed} zeraram · {statsQuery.data.dropped}{' '}
          abandonaram
        </Text>
      )}

      {renderPlayersRow('Quem está jogando', playingQuery.data)}
      {renderPlayersRow('Seus amigos estão jogando', friendsQuery.data)}

      <Text style={styles.sectionTitle}>Seus playthroughs</Text>
      {entriesQuery.isError ? (
        <ErrorState error={entriesQuery.error} onRetry={() => entriesQuery.refetch()} />
      ) : entriesQuery.data?.length ? (
        entriesQuery.data.map((entry) => (
          <Pressable
            key={entry.id}
            style={({ pressed }) => [styles.entryCard, pressed && { opacity: opacity.pressed }]}
            onPress={() => openForm(entry)}
            accessibilityRole="button"
            accessibilityLabel={`Editar playthrough de ${entry.platform}`}
          >
            <View style={styles.entryHeader}>
              <View style={styles.entryPlatformRow}>
                <MaterialCommunityIcons name={getPlatformIcon(entry.platform)} size={icon.sm} color={colors.textPrimary} />
                <Text style={styles.entryPlatform}>{entry.platform}</Text>
              </View>
              <StatusBadge status={entry.status} />
            </View>
            <Text style={styles.entryMeta}>
              {entry.hoursPlayed ? `${entry.hoursPlayed}h` : 'sem horas registradas'}
              {/* Nota é 0–10 no banco: mostrar em 5 arredondava 7 pra 8. */}
              {entry.rating ? ` · nota ${entry.rating}/10` : ''}
            </Text>
          </Pressable>
        ))
      ) : (
        <EmptyState icon="game-controller-outline" title="Você ainda não trackeou esse jogo" />
      )}

      <Button
        label="Postar sobre este jogo"
        icon="create-outline"
        variant="secondary"
        onPress={() =>
          navigation.navigate('CreatePost', { gameId: game.id, gameName: game.name, gameCoverUrl: game.coverUrl })
        }
        size="lg"
        fullWidth
        style={styles.cta}
      />
      <Button label="Novo playthrough" icon="add" onPress={() => openForm()} size="lg" fullWidth style={styles.cta} />

      <Text style={styles.sectionTitle}>Posts sobre o jogo</Text>
    </View>
  );

  return (
    <FlatList
      style={styles.screen}
      data={gamePosts.items}
      keyExtractor={(item) => item.id}
      renderItem={renderPost}
      onEndReached={gamePosts.onEndReached}
      onEndReachedThreshold={0.4}
      contentContainerStyle={styles.list}
      ListHeaderComponent={header}
      ListFooterComponent={<ListFooter loading={gamePosts.isFetchingNextPage} />}
      ListEmptyComponent={
        <ListState
          query={gamePosts}
          empty={{
            icon: 'chatbubbles-outline',
            title: 'Nenhum post sobre este jogo ainda',
            subtitle: 'Seja o primeiro a postar sobre ele',
          }}
        />
      }
    />
  );
}

const styles = StyleSheet.create({
  screen: { backgroundColor: colors.background },
  list: { padding: space.lg, gap: space.xs, paddingBottom: space.xxl },
  cover: {
    width: 140,
    height: 187,
    borderRadius: radius.lg,
    backgroundColor: colors.skeleton,
    alignSelf: 'center',
  },
  title: { ...type.title, color: colors.textPrimary, textAlign: 'center', marginTop: space.md },
  subtitle: { ...type.caption, color: colors.textSecondary, textAlign: 'center', marginTop: space.hair },
  platforms: { ...type.caption, color: colors.accent, textAlign: 'center', marginTop: space.xs },
  summary: { ...type.body, color: colors.textPrimary, marginTop: space.lg },
  screenshots: { marginTop: space.lg },
  screenshotsContent: { gap: space.sm },
  screenshot: { width: 240, height: 135, borderRadius: radius.lg, backgroundColor: colors.skeleton },
  // Contagens são dado: mono.
  stats: { ...type.data, color: colors.textSecondary, textAlign: 'center', marginTop: space.xl },
  sectionTitle: {
    ...type.eyebrow,
    color: colors.textSecondary,
    marginTop: space.xl,
    marginBottom: space.md,
  },
  playersRow: { flexDirection: 'row', flexWrap: 'wrap', gap: space.lg },
  playerItem: { alignItems: 'center', width: 64, gap: space.xs },
  playerName: { ...type.micro, color: colors.textSecondary, textAlign: 'center' },
  entryCard: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    padding: space.lg,
    gap: space.sm,
    marginBottom: space.sm,
  },
  entryHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  entryPlatformRow: { flexDirection: 'row', alignItems: 'center', gap: space.xs },
  entryPlatform: { ...type.bodyStrong, color: colors.textPrimary },
  // Horas e nota em mono: é o dado da ficha.
  entryMeta: { ...type.data, color: colors.textSecondary },
  cta: { marginTop: space.lg },
});
