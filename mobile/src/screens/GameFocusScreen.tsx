import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import * as gameEntriesApi from '../api/gameEntries';
import * as gamesApi from '../api/games';
import { EmptyState } from '../components/EmptyState';
import { ImageViewerModal } from '../components/ImageViewerModal';
import { LoadingState } from '../components/LoadingState';
import { Button, ErrorState, RemoteImage, Screen, StatusBadge } from '../components/ui';
import { getPlatformIcon } from '../lib/platformIcon';
import type { RootStackParamList } from '../navigation/types';
import { colors, icon, opacity, radius, space, type } from '../theme';
import type { GameEntry } from '../types/models';

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

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.container}>
      <RemoteImage uri={game.coverUrl} style={styles.cover} accessibilityLabel={`Capa de ${game.name}`} />
      <Text style={styles.title}>{game.name}</Text>
      {game.genres.length > 0 && <Text style={styles.subtitle}>{game.genres.join(', ')}</Text>}
      {game.platforms.length > 0 && <Text style={styles.platforms}>{game.platforms.slice(0, 5).join(' · ')}</Text>}
      {game.summary && <Text style={styles.summary}>{game.summary}</Text>}

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

      <Button label="Novo playthrough" icon="add" onPress={() => openForm()} size="lg" fullWidth style={styles.cta} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { backgroundColor: colors.background },
  container: { padding: space.lg, gap: space.xs },
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
  sectionTitle: {
    ...type.eyebrow,
    color: colors.textSecondary,
    marginTop: space.xl,
    marginBottom: space.md,
  },
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
