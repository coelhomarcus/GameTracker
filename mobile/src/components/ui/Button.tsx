import { Ionicons } from '@expo/vector-icons';
import { ActivityIndicator, Pressable, StyleSheet, Text, View, type StyleProp, type ViewStyle } from 'react-native';
import { colors, icon as iconSize, opacity, radius, space, type } from '../../theme';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger';
type Size = 'sm' | 'md' | 'lg';

interface Props {
  label: string;
  onPress: () => void;
  variant?: Variant;
  size?: Size;
  loading?: boolean;
  disabled?: boolean;
  fullWidth?: boolean;
  icon?: keyof typeof Ionicons.glyphMap;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
}

const PADDING: Record<Size, { v: number; h: number }> = {
  sm: { v: space.sm, h: space.lg },
  md: { v: space.md, h: space.xl },
  lg: { v: space.lg, h: space.xl },
};

export function Button({
  label,
  onPress,
  variant = 'primary',
  size = 'md',
  loading,
  disabled,
  fullWidth,
  icon,
  accessibilityLabel,
  style,
}: Props) {
  const isOff = disabled || loading;
  const pad = PADDING[size];
  const labelColor = LABEL_COLOR[variant];

  return (
    <Pressable
      onPress={onPress}
      disabled={isOff}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? label}
      accessibilityState={{ disabled: Boolean(isOff), busy: Boolean(loading) }}
      android_ripple={{ color: colors.scrim }}
      style={({ pressed }) => [
        styles.base,
        VARIANT[variant],
        { paddingVertical: pad.v, paddingHorizontal: pad.h },
        fullWidth && styles.fullWidth,
        pressed && !isOff && { opacity: opacity.pressed },
        isOff && { opacity: opacity.disabled },
        style,
      ]}
    >
      {loading ? (
        // Mesma altura do label, para o botão não pular ao entrar em loading.
        <View style={styles.loader}>
          <ActivityIndicator color={labelColor} />
        </View>
      ) : (
        <>
          {icon && <Ionicons name={icon} size={size === 'sm' ? iconSize.md : iconSize.lg} color={labelColor} />}
          <Text style={[styles.label, size === 'sm' ? type.label : type.bodyStrong, { color: labelColor }]}>
            {label}
          </Text>
        </>
      )}
    </Pressable>
  );
}

const LABEL_COLOR: Record<Variant, string> = {
  primary: colors.textOnAccent,
  secondary: colors.textPrimary,
  ghost: colors.accent,
  danger: colors.danger,
};

const VARIANT: Record<Variant, ViewStyle> = {
  primary: { backgroundColor: colors.accent },
  secondary: { borderWidth: 1, borderColor: colors.borderStrong },
  ghost: {},
  danger: { borderWidth: 1, borderColor: colors.danger },
};

const styles = StyleSheet.create({
  base: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: space.sm,
    borderRadius: radius.pill,
  },
  fullWidth: { alignSelf: 'stretch' },
  label: { textAlign: 'center' },
  loader: { height: type.bodyStrong.lineHeight, justifyContent: 'center' },
});
