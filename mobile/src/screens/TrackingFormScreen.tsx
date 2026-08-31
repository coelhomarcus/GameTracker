import DateTimePicker from '@react-native-community/datetimepicker';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import * as gameEntriesApi from '../api/gameEntries';
import { StarRating } from '../components/StarRating';
import { Button, Chip, IconButton, Screen } from '../components/ui';
import { notify } from '../lib/alert';
import { getApiErrorMessage } from '../lib/apiError';
import { parseDecimal, toApiDate } from '../lib/date';
import { STATUS_COLOR, STATUS_LABEL } from '../lib/gameEntryLabels';
import { qk } from '../lib/queryKeys';
import type { RootStackParamList } from '../navigation/types';
import { colors, forms, icon, opacity, radius, space, type } from '../theme';
import type { GameEntryStatus } from '../types/models';

const STATUS_OPTIONS: GameEntryStatus[] = ['backlog', 'playing', 'completed', 'dropped'];

function formatDate(date: Date) {
  return date.toLocaleDateString('pt-BR');
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
      {/* Sem accessibilityRole: quando há uma data, a linha contém o botão real
          de limpar — um <button> não pode conter outro (vira <button> aninhado
          no React Native Web, HTML inválido que quebra a hidratação). */}
      <Pressable
        style={({ pressed }) => [styles.dateRow, pressed && { opacity: opacity.pressed }]}
        onPress={() => setShowPicker(true)}
      >
        <Ionicons name="calendar-outline" size={icon.md} color={colors.textSecondary} />
        <Text style={value ? styles.dateText : styles.datePlaceholder}>
          {value ? formatDate(value) : 'Selecionar data'}
        </Text>
        {value && (
          <IconButton
            name="close-circle"
            size="md"
            onPress={() => onChange(null)}
            accessibilityLabel={`Limpar ${label.toLowerCase()}`}
          />
        )}
      </Pressable>

      {showPicker && (
        <DateTimePicker
          value={value ?? new Date()}
          mode="date"
          display={Platform.OS === 'ios' ? 'inline' : 'default'}
          onValueChange={(_event, date) => {
            // Fecha nas duas plataformas: no iOS o calendário inline ficava
            // aberto pra sempre depois do primeiro toque.
            setShowPicker(false);
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

  const hours = parseDecimal(hoursPlayed);
  const hoursInvalid = hoursPlayed.trim().length > 0 && hours === null;

  const mutation = useMutation({
    mutationFn: () => {
      const payload = {
        platform,
        status,
        ...(startedAt ? { startedAt: toApiDate(startedAt) } : {}),
        ...(finishedAt ? { finishedAt: toApiDate(finishedAt) } : {}),
        ...(hours !== null ? { hoursPlayed: hours } : {}),
        ...(rating ? { rating } : {}),
        ...(notes ? { notes } : {}),
      };
      return isEditing
        ? gameEntriesApi.updateGameEntry(entryId!, payload)
        : gameEntriesApi.createGameEntry({ igdbId, ...payload });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: qk.gameEntries() });
      queryClient.invalidateQueries({ queryKey: ['user-game-entries'] });
      if (!isEditing) notify('Adicionado', `${gameName} foi adicionado aos seus jogos.`);
      navigation.goBack();
    },
  });

  return (
    <Screen keyboard>
      <ScrollView contentContainerStyle={styles.container} keyboardShouldPersistTaps="handled">
        <View style={styles.heading}>
          <Text style={styles.eyebrow}>{isEditing ? 'Editar playthrough' : 'Novo playthrough'}</Text>
          <Text style={styles.title}>{gameName}</Text>
        </View>

        <View style={styles.section}>
          <Text style={forms.label}>Plataforma</Text>
          {platforms.length > 0 ? (
            <View style={styles.chipsRow}>
              {platforms.map((option) => (
                <Chip
                  key={option}
                  label={option}
                  selected={platform === option}
                  onPress={() => setPlatform(option)}
                />
              ))}
            </View>
          ) : (
            <TextInput
              style={forms.input}
              placeholder="Ex: PC, PS5..."
              placeholderTextColor={colors.textTertiary}
              value={platform}
              onChangeText={setPlatform}
              autoCorrect={false}
              accessibilityLabel="Plataforma"
            />
          )}
        </View>

        <View style={styles.section}>
          <Text style={forms.label}>Status</Text>
          <View style={styles.chipsRow}>
            {STATUS_OPTIONS.map((option) => (
              <Chip
                key={option}
                label={STATUS_LABEL[option]}
                selected={status === option}
                onPress={() => setStatus(option)}
                tone="status"
                statusColor={STATUS_COLOR[option]}
              />
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
              style={[forms.input, styles.hoursInput, hoursInvalid && styles.inputInvalid]}
              keyboardType="decimal-pad"
              placeholder="0"
              placeholderTextColor={colors.textTertiary}
              value={hoursPlayed}
              onChangeText={setHoursPlayed}
              accessibilityLabel="Horas jogadas"
            />
            <Text style={styles.hoursSuffix}>horas</Text>
          </View>
          {hoursInvalid && <Text style={styles.fieldError}>Use só números, como 12 ou 12,5.</Text>}
        </View>

        <View style={styles.section}>
          <Text style={forms.label}>Nota</Text>
          <View style={styles.ratingBox}>
            <StarRating value={rating} onChange={setRating} />
            {rating !== null && <Text style={styles.ratingValue}>{rating}/10</Text>}
          </View>
        </View>

        <View style={styles.section}>
          <Text style={forms.label}>Anotações</Text>
          <TextInput
            style={[forms.input, forms.multiline]}
            multiline
            placeholder="O que achou desse playthrough?"
            placeholderTextColor={colors.textTertiary}
            value={notes}
            onChangeText={setNotes}
            accessibilityLabel="Anotações"
          />
        </View>

        {mutation.isError && <Text style={styles.error}>{getApiErrorMessage(mutation.error)}</Text>}

        <Button
          label={isEditing ? 'Salvar alterações' : 'Trackear jogo'}
          onPress={() => mutation.mutate()}
          size="lg"
          fullWidth
          loading={mutation.isPending}
          disabled={!platform || hoursInvalid}
        />
      </ScrollView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  container: { padding: space.lg, paddingBottom: space.huge, gap: space.xl },
  heading: { gap: space.hair },
  eyebrow: { ...type.eyebrow, color: colors.textSecondary },
  title: { ...type.title, color: colors.textPrimary },
  section: { gap: 0 },
  chipsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: space.sm },
  datesRow: { flexDirection: 'row', gap: space.md },
  dateColumn: { flex: 1 },
  dateRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: space.sm,
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    paddingVertical: space.md,
    paddingHorizontal: space.lg,
  },
  // Data é dado: mono mantém as duas colunas alinhadas.
  dateText: { ...type.data, flex: 1, color: colors.textPrimary },
  datePlaceholder: { ...type.caption, flex: 1, color: colors.textTertiary },
  hoursRow: { flexDirection: 'row', alignItems: 'center', gap: space.md },
  hoursInput: { ...type.data, flex: 1, color: colors.textPrimary },
  inputInvalid: { borderWidth: 1, borderColor: colors.danger },
  hoursSuffix: { ...type.caption, color: colors.textSecondary },
  ratingBox: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    paddingVertical: space.lg,
    alignItems: 'center',
    gap: space.sm,
  },
  ratingValue: { ...type.dataLg, color: colors.rating },
  fieldError: { ...type.micro, color: colors.danger, marginTop: space.sm },
  error: { ...type.caption, color: colors.danger },
});
