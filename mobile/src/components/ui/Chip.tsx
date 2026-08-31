import type { ReactNode } from 'react';
import { Pressable, StyleSheet, Text } from 'react-native';
import { colors, opacity, radius, space, type } from '../../theme';

interface Props {
  label: string;
  selected: boolean;
  onPress: () => void;
  /** `status` pinta o chip selecionado com a cor do status em vez do accent. */
  tone?: 'neutral' | 'status';
  statusColor?: string;
  /** Ícone pré-renderizado (o chamador escolhe a família — Ionicons, MaterialCommunityIcons). */
  icon?: ReactNode;
}

export function Chip({ label, selected, onPress, tone = 'neutral', statusColor, icon }: Props) {
  const activeBackground = tone === 'status' && statusColor ? statusColor : colors.accent;
  const activeLabel = tone === 'status' && statusColor ? colors.textOnStatus : colors.textOnAccent;

  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityState={{ selected }}
      accessibilityLabel={label}
      android_ripple={{ color: colors.scrim }}
      style={({ pressed }) => [
        styles.chip,
        selected && { backgroundColor: activeBackground },
        pressed && { opacity: opacity.pressed },
      ]}
    >
      {icon}
      <Text style={[styles.label, selected && { color: activeLabel }]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: space.xs,
    backgroundColor: colors.surface,
    borderRadius: radius.pill,
    paddingVertical: space.sm,
    paddingHorizontal: space.lg,
  },
  label: { ...type.label, color: colors.textSecondary },
});
