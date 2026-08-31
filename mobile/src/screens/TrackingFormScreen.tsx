import { Ionicons } from '@expo/vector-icons';
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
import { STATUS_LABEL } from '../lib/gameEntryLabels';
import type { RootStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';
import { forms } from '../theme/forms';
import { radius } from '../theme/radius';
import type { GameEntryStatus } from '../types/models';

const STATUS_OPTIONS: GameEntryStatus[] = ['backlog', 'playing', 'completed', 'dropped'];

function formatDate(date: Date) {
  return date.toLocaleDateString('pt-BR');
}

function toApiDate(date: Date) {
  return date.toISOString().slice(0, 10);
}

interface DateFieldProps {
  label: string;
  value: Date | null;
  onChange: (value: Date | null) => void;
}

function DateField({ label, value, onChange }: DateFieldProps) {
  const [showPicker, setShowPicker] = useState(false);

  return (
    <View>
      <Text style={forms.label}>{label}</Text>
      <Pressable style={styles.dateRow} onPress={() => setShowPicker(true)}>
        <Ionicons name="calendar-outline" size={18} color={colors.textSecondary} />
        <Text style={value ? styles.dateText : styles.datePlaceholder}>{value ? formatDate(value) : 'Selecionar data'}</Text>
        {value && (
          <Pressable onPress={() => onChange(null)} hitSlop={8}>
            <Ionicons name="close-circle" size={18} color={colors.textSecondary} />
          </Pressable>
        )}
      </Pressable>

      {showPicker && (
        <DateTimePicker
          value={value ?? new Date()}
          mode="date"
          display={Platform.OS === 'ios' ? 'inline' : 'default'}
          onValueChange={(_event, date) => {
            setShowPicker(Platform.OS === 'ios');
            onChange(date);
          }}
          onDismiss={() => setShowPicker(false)}
        />
      )}
    </View>
  );
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
        <View style={styles.heading}>
          <Text style={styles.eyebrow}>{isEditing ? 'Editar playthrough' : 'Novo playthrough'}</Text>
          <Text style={styles.title}>{gameName}</Text>
        </View>

        <View style={styles.section}>
          <Text style={forms.label}>Plataforma</Text>
          {platforms.length > 0 ? (
            <View style={styles.chipsRow}>
              {platforms.map((p) => (
                <Pressable key={p} style={[styles.chip, platform === p && styles.chipActive]} onPress={() => setPlatform(p)}>
                  <Text style={[styles.chipText, platform === p && styles.chipTextActive]}>{p}</Text>
                </Pressable>
              ))}
            </View>
          ) : (
            <TextInput
              style={forms.input}
              placeholder="Ex: PC, PS5..."
              placeholderTextColor={colors.textSecondary}
              value={platform}
              onChangeText={setPlatform}
            />
          )}
        </View>

        <View style={styles.section}>
          <Text style={forms.label}>Status</Text>
          <View style={styles.chipsRow}>
            {STATUS_OPTIONS.map((option) => (
              <Pressable
                key={option}
                style={[styles.chip, status === option && styles.chipActive]}
                onPress={() => setStatus(option)}
              >
                <Text style={[styles.chipText, status === option && styles.chipTextActive]}>{STATUS_LABEL[option]}</Text>
              </Pressable>
            ))}
          </View>
        </View>

        <View style={styles.datesRow}>
          <View style={styles.dateColumn}>
            <DateField label="Início" value={startedAt} onChange={setStartedAt} />
          </View>
          <View style={styles.dateColumn}>
            <DateField label="Fim" value={finishedAt} onChange={setFinishedAt} />
          </View>
        </View>

        <View style={styles.section}>
          <Text style={forms.label}>Horas jogadas</Text>
          <View style={styles.hoursRow}>
            <TextInput
              style={[forms.input, styles.hoursInput]}
              keyboardType="numeric"
              placeholder="0"
              placeholderTextColor={colors.textSecondary}
              value={hoursPlayed}
              onChangeText={setHoursPlayed}
            />
            <Text style={styles.hoursSuffix}>horas</Text>
          </View>
        </View>

        <View style={styles.section}>
          <Text style={forms.label}>Nota</Text>
          <View style={styles.ratingBox}>
            <StarRating value={rating} onChange={setRating} />
          </View>
        </View>

        <View style={styles.section}>
          <Text style={forms.label}>Anotações</Text>
          <TextInput
            style={[forms.input, forms.multiline]}
            multiline
            placeholder="O que achou desse playthrough?"
            placeholderTextColor={colors.textSecondary}
            value={notes}
            onChangeText={setNotes}
          />
        </View>

        {mutation.isError && <Text style={styles.error}>{getApiErrorMessage(mutation.error)}</Text>}

        <Pressable
          style={[styles.button, (!platform || mutation.isPending) && styles.buttonDisabled]}
          disabled={!platform || mutation.isPending}
          onPress={() => mutation.mutate()}
        >
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
  container: { padding: 16, paddingBottom: 40, gap: 20, backgroundColor: colors.background },
  heading: { gap: 2 },
  eyebrow: { fontSize: 13, fontWeight: '600', color: colors.textSecondary },
  title: { fontSize: 22, fontWeight: '700', color: colors.textPrimary },
  section: { gap: 0 },
  chipsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  chip: { backgroundColor: colors.surface, borderRadius: radius.pill, paddingVertical: 8, paddingHorizontal: 14 },
  chipActive: { backgroundColor: colors.accent },
  chipText: { color: colors.textSecondary, fontSize: 13, fontWeight: '600' },
  chipTextActive: { color: '#fff' },
  datesRow: { flexDirection: 'row', gap: 12 },
  dateColumn: { flex: 1 },
  dateRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    paddingVertical: 12,
    paddingHorizontal: 14,
  },
  dateText: { flex: 1, fontSize: 14, color: colors.textPrimary },
  datePlaceholder: { flex: 1, fontSize: 14, color: colors.textSecondary },
  hoursRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  hoursInput: { flex: 1 },
  hoursSuffix: { color: colors.textSecondary, fontSize: 14 },
  ratingBox: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    paddingVertical: 14,
    alignItems: 'center',
  },
  button: { backgroundColor: colors.accent, borderRadius: radius.pill, padding: 16, alignItems: 'center', marginTop: 4 },
  buttonDisabled: { opacity: 0.5 },
  buttonText: { color: '#fff', fontWeight: '700', fontSize: 15 },
  error: { color: colors.like },
});
