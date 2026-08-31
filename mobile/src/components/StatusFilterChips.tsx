import { Ionicons } from '@expo/vector-icons';
import { ScrollView, StyleSheet } from 'react-native';
import { STATUS_COLOR, STATUS_FILTERS, STATUS_ICON } from '../lib/gameEntryLabels';
import { colors, icon as iconScale, space } from '../theme';
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
      style={styles.scroll}
      contentContainerStyle={styles.row}
      keyboardShouldPersistTaps="handled"
    >
      {STATUS_FILTERS.map((filter) => {
        const selected = value === filter.value;
        return (
          <Chip
            key={filter.value}
            label={filter.label}
            selected={selected}
            onPress={() => onChange(filter.value)}
            // O filtro pinta com a própria cor do status — o chip vira legenda.
            tone={filter.value === 'all' ? 'neutral' : 'status'}
            statusColor={filter.value === 'all' ? undefined : STATUS_COLOR[filter.value]}
            icon={
              filter.value !== 'all' && (
                <Ionicons
                  name={STATUS_ICON[filter.value]}
                  size={iconScale.sm}
                  color={selected ? colors.textOnStatus : colors.textSecondary}
                />
              )
            }
          />
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  // flexGrow: 0 é essencial no Android: sem altura própria, um ScrollView
  // horizontal pode se expandir pra ocupar espaço vertical além do seu conteúdo.
  scroll: { flexGrow: 0 },
  row: { gap: space.sm, paddingHorizontal: space.lg, paddingVertical: space.md },
});
