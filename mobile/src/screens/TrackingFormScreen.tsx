import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import DateTimePicker from '@react-native-community/datetimepicker';
import { useState } from 'react';
import { ActivityIndicator, Alert, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import * as gameEntriesApi from '../api/gameEntries';
import { KeyboardAvoidingScreen } from '../components/KeyboardAvoidingScreen';
import { StarRating } from '../components/StarRating';
import { getApiErrorMessage } from '../lib/apiError';
import type { RootStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';
import { radius } from '../theme/radius';
import type { GameEntryStatus } from '../types/models';

const STATUS_OPTIONS: { value: GameEntryStatus; label: string }[] = [
  { value: 'backlog', label: 'Backlog' },
  { value: 'playing', label: 'Jogando' },
  { value: 'completed', label: 'Completo' },
  { value: 'dropped', label: 'Abandonado' },
];

function formatDate(date: Date) {
  return date.toLocaleDateString('pt-BR');
}

function toApiDate(date: Date) {
  return date.toISOString().slice(0, 10);
}

export default function TrackingFormScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'TrackingForm'>>();
  const { igdbId, gameName, platforms, entryId, initial } = route.params;
  const queryClient = useQueryClient();
  const isEditing = !!entryId;

  const [platform, setPlatform] = useState(initial?.platform ?? platforms[0] ?? '');
  const [status, setStatus] = useState<GameEntryStatus>(initial?.status ?? 'backlog');
  const [startedAt, setStartedAt] = useState<Date | null>(initial?.startedAt ? new Date(initial.startedAt) : null);
  const [finishedAt, setFinishedAt] = useState<Date | null>(initial?.finishedAt ? new Date(initial.finishedAt) : null);
  const [hoursPlayed, setHoursPlayed] = useState(initial?.hoursPlayed ?? '');
  const [rating, setRating] = useState<number | null>(initial?.rating ?? null);
  const [notes, setNotes] = useState(initial?.notes ?? '');
  const [showStartPicker, setShowStartPicker] = useState(false);
  const [showFinishPicker, setShowFinishPicker] = useState(false);

  const mutation = useMutation({
    mutationFn: () => {
      const payload = {
        platform,
        status,
        ...(startedAt ? { startedAt: toApiDate(startedAt) } : {}),
        ...(finishedAt ? { finishedAt: toApiDate(finishedAt) } : {}),
        ...(hoursPlayed ? { hoursPlayed: Number(hoursPlayed) } : {}),
        ...(rating ? { rating } : {}),
        ...(notes ? { notes } : {}),
      };
      return isEditing ? gameEntriesApi.updateGameEntry(entryId!, payload) : gameEntriesApi.createGameEntry({ igdbId, ...payload });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['game-entries'] });
      if (!isEditing) {
        Alert.alert('Adicionado', `${gameName} foi adicionado aos seus jogos.`);
      }
      navigation.goBack();
    },
  });

  return (
    <KeyboardAvoidingScreen>
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>{isEditing ? 'Editar playthrough' : 'Novo playthrough'}</Text>
      <Text style={styles.subtitle}>{gameName}</Text>

      <Text style={styles.label}>Plataforma</Text>
      {platforms.length > 0 ? (
        <View style={styles.chipsRow}>
          {platforms.map((p) => (
            <Pressable key={p} style={[styles.chip, platform === p && styles.chipActive]} onPress={() => setPlatform(p)}>
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

      <Text style={styles.label}>Início</Text>
      <Pressable style={styles.dateInput} onPress={() => setShowStartPicker(true)}>
        <Text style={startedAt ? styles.dateText : styles.datePlaceholder}>
          {startedAt ? formatDate(startedAt) : 'Selecionar data'}
        </Text>
      </Pressable>
      {showStartPicker && (
        <DateTimePicker
          value={startedAt ?? new Date()}
          mode="date"
          display={Platform.OS === 'ios' ? 'inline' : 'default'}
          onValueChange={(_event, date) => {
            setShowStartPicker(Platform.OS === 'ios');
            setStartedAt(date);
          }}
          onDismiss={() => setShowStartPicker(false)}
        />
      )}

      <Text style={styles.label}>Fim</Text>
      <Pressable style={styles.dateInput} onPress={() => setShowFinishPicker(true)}>
        <Text style={finishedAt ? styles.dateText : styles.datePlaceholder}>
          {finishedAt ? formatDate(finishedAt) : 'Selecionar data'}
        </Text>
      </Pressable>
      {showFinishPicker && (
        <DateTimePicker
          value={finishedAt ?? new Date()}
          mode="date"
          display={Platform.OS === 'ios' ? 'inline' : 'default'}
          onValueChange={(_event, date) => {
            setShowFinishPicker(Platform.OS === 'ios');
            setFinishedAt(date);
          }}
          onDismiss={() => setShowFinishPicker(false)}
        />
      )}

      <Text style={styles.label}>Horas jogadas</Text>
      <TextInput style={styles.input} keyboardType="numeric" value={hoursPlayed} onChangeText={setHoursPlayed} />

      <Text style={styles.label}>Nota</Text>
      <StarRating value={rating} onChange={setRating} />

      <Text style={styles.label}>Notas</Text>
      <TextInput style={[styles.input, styles.notesInput]} multiline value={notes} onChangeText={setNotes} />

      {mutation.isError && <Text style={styles.error}>{getApiErrorMessage(mutation.error)}</Text>}

      <Pressable style={styles.button} disabled={!platform || mutation.isPending} onPress={() => mutation.mutate()}>
        {mutation.isPending ? (
          <ActivityIndicator color="#fff" />
        ) : (
          <Text style={styles.buttonText}>{isEditing ? 'Salvar alterações' : 'Trackear jogo'}</Text>
        )}
      </Pressable>
    </ScrollView>
    </KeyboardAvoidingScreen>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16, gap: 4, backgroundColor: colors.background },
  title: { fontSize: 20, fontWeight: '700', textAlign: 'center', marginTop: 4, color: colors.textPrimary },
  subtitle: { fontSize: 14, color: colors.textSecondary, textAlign: 'center', marginBottom: 8 },
  label: { fontSize: 14, fontWeight: '600', marginTop: 12, marginBottom: 6, color: colors.textPrimary },
  input: { borderWidth: 1, borderColor: colors.border, borderRadius: 8, padding: 12, fontSize: 16, color: colors.textPrimary },
  dateInput: { borderWidth: 1, borderColor: colors.border, borderRadius: 8, padding: 12 },
  dateText: { fontSize: 16, color: colors.textPrimary },
  datePlaceholder: { fontSize: 16, color: colors.textSecondary },
  notesInput: { minHeight: 80, textAlignVertical: 'top' },
  chipsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  chip: { borderWidth: 1, borderColor: colors.border, borderRadius: 16, paddingVertical: 6, paddingHorizontal: 12 },
  chipActive: { backgroundColor: colors.accent, borderColor: colors.accent },
  chipText: { color: colors.textPrimary },
  chipTextActive: { color: '#fff', fontWeight: '600' },
  button: { backgroundColor: colors.accent, borderRadius: radius.pill, padding: 14, alignItems: 'center', marginTop: 20 },
  buttonText: { color: '#fff', fontWeight: '600', fontSize: 16 },
  error: { color: colors.like, marginTop: 8 },
});
