import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Image,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import * as gameEntriesApi from '../api/gameEntries';
import { getApiErrorMessage } from '../lib/apiError';
import type { RootStackParamList } from '../navigation/types';
import type { GameEntryStatus } from '../types/models';

const STATUS_OPTIONS: { value: GameEntryStatus; label: string }[] = [
  { value: 'backlog', label: 'Backlog' },
  { value: 'playing', label: 'Jogando' },
  { value: 'completed', label: 'Completo' },
  { value: 'dropped', label: 'Abandonado' },
];

export default function GameDetailScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'GameDetail'>>();
  const game = route.params;
  const queryClient = useQueryClient();

  const [platform, setPlatform] = useState(game.platforms[0] ?? '');
  const [status, setStatus] = useState<GameEntryStatus>('backlog');
  const [startedAt, setStartedAt] = useState('');
  const [finishedAt, setFinishedAt] = useState('');
  const [hoursPlayed, setHoursPlayed] = useState('');
  const [rating, setRating] = useState('');
  const [notes, setNotes] = useState('');

  const mutation = useMutation({
    mutationFn: () =>
      gameEntriesApi.createGameEntry({
        igdbId: game.igdbId,
        platform,
        status,
        ...(startedAt ? { startedAt } : {}),
        ...(finishedAt ? { finishedAt } : {}),
        ...(hoursPlayed ? { hoursPlayed: Number(hoursPlayed) } : {}),
        ...(rating ? { rating: Number(rating) } : {}),
        ...(notes ? { notes } : {}),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['game-entries'] });
      Alert.alert('Adicionado', `${game.name} foi adicionado aos seus jogos.`);
      navigation.goBack();
    },
  });

  return (
    <ScrollView contentContainerStyle={styles.container}>
      {game.coverUrl ? (
        <Image source={{ uri: game.coverUrl }} style={styles.cover} />
      ) : (
        <View style={[styles.cover, styles.coverPlaceholder]} />
      )}
      <Text style={styles.title}>{game.name}</Text>
      {game.genres.length > 0 && <Text style={styles.subtitle}>{game.genres.join(', ')}</Text>}

      <Text style={styles.label}>Plataforma</Text>
      {game.platforms.length > 0 ? (
        <View style={styles.chipsRow}>
          {game.platforms.map((p) => (
            <Pressable
              key={p}
              style={[styles.chip, platform === p && styles.chipActive]}
              onPress={() => setPlatform(p)}
            >
              <Text style={[styles.chipText, platform === p && styles.chipTextActive]}>{p}</Text>
            </Pressable>
          ))}
        </View>
      ) : (
        <TextInput style={styles.input} placeholder="Ex: PC, PS5..." value={platform} onChangeText={setPlatform} />
      )}

      <Text style={styles.label}>Status</Text>
      <View style={styles.chipsRow}>
        {STATUS_OPTIONS.map((option) => (
          <Pressable
            key={option.value}
            style={[styles.chip, status === option.value && styles.chipActive]}
            onPress={() => setStatus(option.value)}
          >
            <Text style={[styles.chipText, status === option.value && styles.chipTextActive]}>{option.label}</Text>
          </Pressable>
        ))}
      </View>

      <Text style={styles.label}>Início (AAAA-MM-DD)</Text>
      <TextInput style={styles.input} placeholder="2026-08-01" value={startedAt} onChangeText={setStartedAt} />

      <Text style={styles.label}>Fim (AAAA-MM-DD)</Text>
      <TextInput style={styles.input} placeholder="2026-08-20" value={finishedAt} onChangeText={setFinishedAt} />

      <Text style={styles.label}>Horas jogadas</Text>
      <TextInput style={styles.input} keyboardType="numeric" value={hoursPlayed} onChangeText={setHoursPlayed} />

      <Text style={styles.label}>Nota (1-10)</Text>
      <TextInput style={styles.input} keyboardType="numeric" value={rating} onChangeText={setRating} />

      <Text style={styles.label}>Notas</Text>
      <TextInput
        style={[styles.input, styles.notesInput]}
        multiline
        value={notes}
        onChangeText={setNotes}
      />

      {mutation.isError && <Text style={styles.error}>{getApiErrorMessage(mutation.error)}</Text>}

      <Pressable style={styles.button} disabled={!platform || mutation.isPending} onPress={() => mutation.mutate()}>
        {mutation.isPending ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Trackear jogo</Text>}
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16, gap: 4 },
  cover: { width: 120, height: 160, borderRadius: 8, backgroundColor: '#eee', alignSelf: 'center' },
  coverPlaceholder: {},
  title: { fontSize: 22, fontWeight: '700', textAlign: 'center', marginTop: 12 },
  subtitle: { fontSize: 14, color: '#666', textAlign: 'center', marginBottom: 8 },
  label: { fontSize: 14, fontWeight: '600', marginTop: 12, marginBottom: 6 },
  input: { borderWidth: 1, borderColor: '#ccc', borderRadius: 8, padding: 12, fontSize: 16 },
  notesInput: { minHeight: 80, textAlignVertical: 'top' },
  chipsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  chip: { borderWidth: 1, borderColor: '#ccc', borderRadius: 16, paddingVertical: 6, paddingHorizontal: 12 },
  chipActive: { backgroundColor: '#4f46e5', borderColor: '#4f46e5' },
  chipText: { color: '#333' },
  chipTextActive: { color: '#fff', fontWeight: '600' },
  button: { backgroundColor: '#4f46e5', borderRadius: 8, padding: 14, alignItems: 'center', marginTop: 20 },
  buttonText: { color: '#fff', fontWeight: '600', fontSize: 16 },
  error: { color: '#dc2626', marginTop: 8 },
});
