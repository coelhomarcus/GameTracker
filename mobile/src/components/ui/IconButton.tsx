import { Ionicons } from '@expo/vector-icons';
import { Pressable, StyleSheet, type StyleProp, type ViewStyle } from 'react-native';
import { colors, hit, icon as iconScale, opacity, radius, space } from '../../theme';

interface Props {
  name: keyof typeof Ionicons.glyphMap;
  onPress: () => void;
  /** Obrigatório de propósito: é o type checker cobrando acessibilidade. */
  accessibilityLabel: string;
  size?: keyof typeof iconScale;
  color?: string;
  hitSlop?: number;
  variant?: 'plain' | 'filled';
  disabled?: boolean;
  style?: StyleProp<ViewStyle>;
}

export function IconButton({
  name,
  onPress,
  accessibilityLabel,
  size = 'lg',
  color = colors.textSecondary,
  hitSlop = hit.md,
  variant = 'plain',
  disabled,
  style,
}: Props) {
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      hitSlop={hitSlop}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      accessibilityState={{ disabled: Boolean(disabled) }}
      android_ripple={{ color: colors.scrim, borderless: variant === 'plain' }}
      style={({ pressed }) => [
        styles.base,
        variant === 'filled' && styles.filled,
        pressed && !disabled && { opacity: opacity.pressed },
        disabled && { opacity: opacity.disabled },
        style,
      ]}
    >
      <Ionicons name={name} size={iconScale[size]} color={variant === 'filled' ? colors.textOnAccent : color} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: { alignItems: 'center', justifyContent: 'center', padding: space.sm },
  filled: { backgroundColor: colors.accent, borderRadius: radius.pill },
});
