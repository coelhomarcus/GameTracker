import { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, opacity, radius, space, type } from '../../theme';
import { IconButton } from './IconButton';

interface Props {
  value: Date | null;
  onChange: (date: Date) => void;
}

// Domingo primeiro: convenção de calendário no pt-BR (diferente do ISO 8601,
// que começa na segunda).
const WEEKDAY_LABELS = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
const MONTH_LABELS = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

function isSameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function cellKey(date: Date) {
  return `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
}

/**
 * Grid do mês, célula por célula — sempre múltiplo de 7, com dias do mês
 * anterior/seguinte preenchendo as pontas (esmaecidos, mas tocáveis, pra
 * trocar de mês sem precisar das setas). Tudo com o construtor local de Date
 * (year, month, day) — nunca parse de string, que é o que causa o bug
 * clássico de "dia errado" em fuso negativo.
 */
function buildMonthGrid(year: number, month: number): Date[] {
  const firstWeekday = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const totalCells = Math.ceil((firstWeekday + daysInMonth) / 7) * 7;

  return Array.from({ length: totalCells }, (_, i) => new Date(year, month, 1 - firstWeekday + i));
}

/** Calendário próprio (sem depender do picker nativo do SO) — mês por vez, sem seleção de range. */
export function Calendar({ value, onChange }: Props) {
  const today = new Date();
  const [viewing, setViewing] = useState(value ?? today);

  const year = viewing.getFullYear();
  const month = viewing.getMonth();
  const grid = buildMonthGrid(year, month);

  function changeMonth(delta: number) {
    setViewing(new Date(year, month + delta, 1));
  }

  return (
    <View>
      <View style={styles.header}>
        <IconButton name="chevron-back" onPress={() => changeMonth(-1)} accessibilityLabel="Mês anterior" />
        <Text style={styles.headerLabel}>
          {MONTH_LABELS[month]} {year}
        </Text>
        <IconButton name="chevron-forward" onPress={() => changeMonth(1)} accessibilityLabel="Próximo mês" />
      </View>

      <View style={styles.weekdayRow}>
        {WEEKDAY_LABELS.map((label, i) => (
          <Text key={i} style={styles.weekdayLabel}>
            {label}
          </Text>
        ))}
      </View>

      <View style={styles.grid}>
        {grid.map((day) => {
          const inMonth = day.getMonth() === month;
          const selected = value ? isSameDay(day, value) : false;
          const isToday = isSameDay(day, today);

          return (
            <Pressable
              key={cellKey(day)}
              onPress={() => onChange(day)}
              accessibilityRole="button"
              accessibilityLabel={day.toLocaleDateString('pt-BR')}
              accessibilityState={{ selected }}
              style={styles.cellWrap}
            >
              {({ pressed }) => (
                <View style={[styles.cell, selected && styles.cellSelected, pressed && !selected && { opacity: opacity.pressed }]}>
                  <Text
                    style={[
                      styles.cellText,
                      !inMonth && styles.cellTextOutside,
                      isToday && !selected && styles.cellTextToday,
                      selected && styles.cellTextSelected,
                    ]}
                  >
                    {day.getDate()}
                  </Text>
                </View>
              )}
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: space.sm },
  headerLabel: { ...type.bodyStrong, color: colors.textPrimary, textTransform: 'capitalize' },
  weekdayRow: { flexDirection: 'row' },
  weekdayLabel: {
    ...type.label,
    width: `${100 / 7}%`,
    textAlign: 'center',
    color: colors.textTertiary,
    paddingBottom: space.xs,
  },
  grid: { flexDirection: 'row', flexWrap: 'wrap' },
  cellWrap: { width: `${100 / 7}%`, aspectRatio: 1, alignItems: 'center', justifyContent: 'center' },
  cell: { width: '78%', aspectRatio: 1, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center' },
  cellSelected: { backgroundColor: colors.accent },
  cellText: { ...type.body, color: colors.textPrimary },
  cellTextOutside: { color: colors.textTertiary },
  cellTextToday: { color: colors.accent, fontFamily: type.bodyStrong.fontFamily },
  cellTextSelected: { color: colors.textOnAccent, fontFamily: type.bodyStrong.fontFamily },
});
