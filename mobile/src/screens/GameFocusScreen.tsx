import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Image, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import * as gameEntriesApi from '../api/gameEntries';
import * as gamesApi from '../api/games';
import { EmptyState } from '../components/EmptyState';
import { ImageViewerModal } from '../components/ImageViewerModal';
import { LoadingState } from '../components/LoadingState';
import { STATUS_LABEL } from '../lib/gameEntryLabels';
import type { RootStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';
import { radius } from '../theme/radius';
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

  if (gameQuery.isLoading || !gameQuery.data) {
    return <LoadingState fullScreen />;
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
    <ScrollView contentContainerStyle={styles.container}>
      {game.coverUrl ? (
        <Image source={{ uri: game.coverUrl }} style={styles.cover} />
      ) : (
        <View style={[styles.cover, styles.coverPlaceholder]} />
      )}
      <Text style={styles.title}>{game.name}</Text>
      {game.genres.length > 0 && <Text style={styles.subtitle}>{game.genres.join(', ')}</Text>}
      {game.platforms.length > 0 && <Text style={styles.platforms}>{game.platforms.slice(0, 5).join(' · ')}</Text>}
      {game.summary && <Text style={styles.summary}>{game.summary}</Text>}

      {game.screenshots.length > 0 && (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.screenshots} contentContainerStyle={styles.screenshotsContent}>
          {game.screenshots.map((url, index) => (
            <Pressable key={url} onPress={() => setViewerIndex(index)}>
              <Image source={{ uri: url }} style={styles.screenshot} />
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
      {entriesQuery.data?.length ? (
        entriesQuery.data.map((entry) => (
          <Pressable key={entry.id} style={styles.entryCard} onPress={() => openForm(entry)}>
            <View style={styles.entryHeader}>
              <Text style={styles.entryPlatform}>{entry.platform}</Text>
              <View style={styles.badge}>
                <Text style={styles.badgeText}>{STATUS_LABEL[entry.status]}</Text>
              </View>
            </View>
            <Text style={styles.entryMeta}>
              {entry.hoursPlayed ? `${entry.hoursPlayed}h` : 'sem horas registradas'}
              {entry.rating ? ` · nota ${Math.round(entry.rating / 2)}/5` : ''}
            </Text>
          </Pressable>
        ))
      ) : (
        <EmptyState icon="game-controller-outline" title="Você ainda não trackeou esse jogo" />
      )}

      <Pressable style={styles.button} onPress={() => openForm()}>
        <Text style={styles.buttonText}>+ Novo playthrough</Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16, gap: 4, backgroundColor: colors.background },
  cover: { width: 140, height: 187, borderRadius: radius.md, backgroundColor: colors.backgroundElevated, alignSelf: 'center' },
  coverPlaceholder: {},
  title: { fontSize: 22, fontWeight: '700', textAlign: 'center', marginTop: 12, color: colors.textPrimary },
  subtitle: { fontSize: 14, color: colors.textSecondary, textAlign: 'center', marginTop: 2 },
  platforms: { fontSize: 13, color: colors.accent, textAlign: 'center', marginTop: 4 },
  summary: { fontSize: 14, color: colors.textPrimary, lineHeight: 20, marginTop: 16 },
  screenshots: { marginTop: 16 },
  screenshotsContent: { gap: 8 },
  screenshot: { width: 240, height: 135, borderRadius: radius.md, backgroundColor: colors.backgroundElevated },
  sectionTitle: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0.6,
    textTransform: 'uppercase',
    marginTop: 28,
    marginBottom: 10,
    color: colors.textSecondary,
  },
  entryCard: { backgroundColor: colors.backgroundElevated, borderRadius: radius.md, padding: 14, gap: 6, marginBottom: 8 },
  entryHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  entryPlatform: { fontSize: 15, fontWeight: '600', color: colors.textPrimary },
  badge: { backgroundColor: colors.background, borderRadius: radius.pill, paddingVertical: 4, paddingHorizontal: 10 },
  badgeText: { color: colors.accent, fontSize: 12, fontWeight: '600' },
  entryMeta: { color: colors.textSecondary, fontSize: 13 },
  button: { backgroundColor: colors.accent, borderRadius: radius.pill, padding: 14, alignItems: 'center', marginTop: 16 },
  buttonText: { color: '#fff', fontWeight: '600', fontSize: 16 },
});
