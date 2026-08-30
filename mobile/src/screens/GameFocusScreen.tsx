import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQuery } from '@tanstack/react-query';
import { ActivityIndicator, Image, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import * as gameEntriesApi from '../api/gameEntries';
import * as gamesApi from '../api/games';
import { STATUS_LABEL } from '../lib/gameEntryLabels';
import type { RootStackParamList } from '../navigation/types';
import type { GameEntry } from '../types/models';

export default function GameFocusScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'GameFocus'>>();
  const { igdbId } = route.params;

  const gameQuery = useQuery({
    queryKey: ['game-focus', igdbId],
    queryFn: () => gamesApi.getGameByIgdb(igdbId),
  });

  const entriesQuery = useQuery({
    queryKey: ['game-entries', 'igdb', igdbId],
    queryFn: () => gameEntriesApi.listMyGameEntries({ igdbId }),
  });

  if (gameQuery.isLoading || !gameQuery.data) {
    return (
      <View style={styles.center}>
        <ActivityIndicator />
      </View>
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
          {game.screenshots.map((url) => (
            <Image key={url} source={{ uri: url }} style={styles.screenshot} />
          ))}
        </ScrollView>
      )}

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
              {entry.rating ? ` · nota ${entry.rating}` : ''}
            </Text>
          </Pressable>
        ))
      ) : (
        <Text style={styles.empty}>Você ainda não trackeou esse jogo</Text>
      )}

      <Pressable style={styles.button} onPress={() => openForm()}>
        <Text style={styles.buttonText}>+ Novo playthrough</Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  container: { padding: 16, gap: 4 },
  cover: { width: 140, height: 187, borderRadius: 8, backgroundColor: '#eee', alignSelf: 'center' },
  coverPlaceholder: {},
  title: { fontSize: 22, fontWeight: '700', textAlign: 'center', marginTop: 12 },
  subtitle: { fontSize: 14, color: '#666', textAlign: 'center', marginTop: 2 },
  platforms: { fontSize: 13, color: '#4f46e5', textAlign: 'center', marginTop: 4 },
  summary: { fontSize: 14, color: '#333', lineHeight: 20, marginTop: 16 },
  screenshots: { marginTop: 16 },
  screenshotsContent: { gap: 8 },
  screenshot: { width: 240, height: 135, borderRadius: 8, backgroundColor: '#eee' },
  sectionTitle: { fontSize: 16, fontWeight: '700', marginTop: 24, marginBottom: 8 },
  empty: { color: '#666' },
  entryCard: { borderWidth: 1, borderColor: '#eee', borderRadius: 10, padding: 12, gap: 4, marginBottom: 8 },
  entryHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  entryPlatform: { fontSize: 15, fontWeight: '600' },
  badge: { backgroundColor: '#eef2ff', borderRadius: 12, paddingVertical: 3, paddingHorizontal: 8 },
  badgeText: { color: '#4f46e5', fontSize: 12, fontWeight: '600' },
  entryMeta: { color: '#666', fontSize: 13 },
  button: { backgroundColor: '#4f46e5', borderRadius: 8, padding: 14, alignItems: 'center', marginTop: 16 },
  buttonText: { color: '#fff', fontWeight: '600', fontSize: 16 },
});
