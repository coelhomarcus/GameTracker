import { Ionicons, MaterialCommunityIcons } from '@expo/vector-icons';
import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import * as gameEntriesApi from '../api/gameEntries';
import { StarRating, starsFromRating } from '../components/StarRating';
import { Button, Chip, DatePickerField, Screen } from '../components/ui';
import { notify } from '../lib/alert';
import { getApiErrorMessage } from '../lib/apiError';
import { fromApiDate, parseDecimal, toApiDate } from '../lib/date';
import { STATUS_COLOR, STATUS_ICON, STATUS_LABEL } from '../lib/gameEntryLabels';
import { getPlatformIcon } from '../lib/platformIcon';
import { qk } from '../lib/queryKeys';
import type { RootStackParamList } from '../navigation/types';
import { colors, forms, icon, radius, space, type } from '../theme';
import type { GameEntryStatus } from '../types/models';

const STATUS_OPTIONS: GameEntryStatus[] = ['backlog', 'playing', 'completed', 'dropped'];

// Teto do numeric(6,1) do banco (5 dígitos + 1 casa decimal) — sem data
// nenhuma preenchida, é o único limite que dá pra calcular.
const MAX_REALISTIC_HOURS = 99999;

/**
 * Ninguém joga mais horas do que existem entre o início e o fim (ou hoje, se
 * ainda estiver jogando) — cada dia civil rende no máximo 24h corridas.
 * Sem data de início, cai no teto absoluto do banco.
 */
function maxPlausibleHours(startedAt: Date | null, finishedAt: Date | null): number {
  if (!startedAt) return MAX_REALISTIC_HOURS;

  const end = finishedAt ?? new Date();
  const startDay = new Date(startedAt.getFullYear(), startedAt.getMonth(), startedAt.getDate());
  const endDay = new Date(end.getFullYear(), end.getMonth(), end.getDate());
  const daysElapsed = Math.round((endDay.getTime() - startDay.getTime()) / 86_400_000) + 1;

  if (daysElapsed <= 0) return MAX_REALISTIC_HOURS;
  return Math.min(daysElapsed * 24, MAX_REALISTIC_HOURS);
}

export default function TrackingFormScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'TrackingForm'>>();
  const { igdbId, gameName, platforms, entryId, initial } = route.params;
  const queryClient = useQueryClient();
  const isEditing = !!entryId;

  const [platform, setPlatform] = useState(initial?.platform ?? platforms[0] ?? '');
  const [status, setStatus] = useState<GameEntryStatus>(initial?.status ?? 'backlog');
  const [startedAt, setStartedAt] = useState<Date | null>(initial?.startedAt ? fromApiDate(initial.startedAt) : null);
  const [finishedAt, setFinishedAt] = useState<Date | null>(initial?.finishedAt ? fromApiDate(initial.finishedAt) : null);
  const [hoursPlayed, setHoursPlayed] = useState(initial?.hoursPlayed ?? '');
  const [rating, setRating] = useState<number | null>(initial?.rating ?? null);
  const [notes, setNotes] = useState(initial?.notes ?? '');

  const hours = parseDecimal(hoursPlayed);
  const hoursMax = maxPlausibleHours(startedAt, finishedAt);
  const hoursNaN = hoursPlayed.trim().length > 0 && hours === null;
  const hoursTooHigh = hours !== null && hours > hoursMax;
  const hoursInvalid = hoursNaN || hoursTooHigh;

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
              {platforms.map((option) => {
                const selected = platform === option;
                return (
                  <Chip
                    key={option}
                    label={option}
                    selected={selected}
                    onPress={() => setPlatform(option)}
                    icon={
                      <MaterialCommunityIcons
                        name={getPlatformIcon(option)}
                        size={icon.sm}
                        color={selected ? colors.textOnAccent : colors.textSecondary}
                      />
                    }
                  />
                );
              })}
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
            {STATUS_OPTIONS.map((option) => {
              const selected = status === option;
              return (
                <Chip
                  key={option}
                  label={STATUS_LABEL[option]}
                  selected={selected}
                  onPress={() => setStatus(option)}
                  tone="status"
                  statusColor={STATUS_COLOR[option]}
                  icon={
                    <Ionicons
                      name={STATUS_ICON[option]}
                      size={icon.sm}
                      color={selected ? colors.textOnStatus : colors.textSecondary}
                    />
                  }
                />
              );
            })}
          </View>
        </View>

        <View style={styles.datesRow}>
          <View style={styles.dateColumn}>
            <DatePickerField label="Início" value={startedAt} onChange={setStartedAt} />
          </View>
          <View style={styles.dateColumn}>
            <DatePickerField label="Fim" value={finishedAt} onChange={setFinishedAt} />
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
          {hoursNaN && <Text style={styles.fieldError}>Use só números, como 12 ou 12,5.</Text>}
          {hoursTooHigh &&
            (startedAt ? (
              <Text style={styles.fieldError}>
                Isso passa das {hoursMax}h possíveis entre {finishedAt ? 'início e fim' : 'o início e hoje'} — confere a data.
              </Text>
            ) : (
              <Text style={styles.fieldError}>Essas horas não são reais — confere o número.</Text>
            ))}
        </View>

        <View style={styles.section}>
          <Text style={forms.label}>Nota</Text>
          <View style={styles.ratingBox}>
            <StarRating value={rating} onChange={setRating} />
            {/* Mesma conta que decide quantas estrelas acendem — nunca destoa
                do que a pessoa está vendo, mesmo com nota ímpar vinda de fora
                deste formulário (ex.: dado antigo/seed). */}
            {rating !== null && <Text style={styles.ratingValue}>{starsFromRating(rating)}/5</Text>}
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
