import { Pressable, ScrollView, StyleSheet, Text } from 'react-native';
import { STATUS_FILTERS } from '../lib/gameEntryLabels';
import { colors } from '../theme/colors';
import { radius } from '../theme/radius';
import type { GameEntryStatus } from '../types/models';

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
      {STATUS_FILTERS.map((filter) => {
        const active = value === filter.value;
        return (
          <Pressable key={filter.value} style={[styles.chip, active && styles.chipActive]} onPress={() => onChange(filter.value)}>
            <Text style={[styles.text, active && styles.textActive]}>{filter.label}</Text>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  row: { gap: 8, paddingHorizontal: 16, paddingVertical: 12 },
  chip: {
    backgroundColor: colors.surface,
    borderRadius: radius.pill,
    paddingVertical: 6,
    paddingHorizontal: 14,
  },
  chipActive: { backgroundColor: colors.accent },
  text: { color: colors.textSecondary, fontSize: 13, fontWeight: '600' },
  textActive: { color: '#fff' },
});
