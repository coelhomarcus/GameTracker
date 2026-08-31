import { ScrollView, StyleSheet } from 'react-native';
import { STATUS_COLOR, STATUS_FILTERS } from '../lib/gameEntryLabels';
import { space } from '../theme';
import type { GameEntryStatus } from '../types/models';
import { Chip } from './ui';

interface Props {
  value: GameEntryStatus | 'all';
  onChange: (value: GameEntryStatus | 'all') => void;
}

export function StatusFilterChips({ value, onChange }: Props) {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={styles.row}
      keyboardShouldPersistTaps="handled"
    >
      {STATUS_FILTERS.map((filter) => (
        <Chip
          key={filter.value}
          label={filter.label}
          selected={value === filter.value}
          onPress={() => onChange(filter.value)}
          // O filtro pinta com a própria cor do status — o chip vira legenda.
          tone={filter.value === 'all' ? 'neutral' : 'status'}
          statusColor={filter.value === 'all' ? undefined : STATUS_COLOR[filter.value]}
        />
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  row: { gap: space.sm, paddingHorizontal: space.lg, paddingVertical: space.md },
});
