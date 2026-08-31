import { Ionicons } from '@expo/vector-icons';
import { Pressable, StyleSheet, View } from 'react-native';
import { colors, hit, opacity, space } from '../theme';

interface Props {
  /** Nota 0–10 (o backend guarda nessa escala). */
  value: number | null;
  onChange: (value: number) => void;
  size?: number;
}

const STARS = [1, 2, 3, 4, 5];

/** Widget de entrada: 5 estrelas escrevem 0–10. A exibição da nota é numérica. */
export function StarRating({ value, onChange, size = 36 }: Props) {
  const filledStars = value ? Math.round(value / 2) : 0;

  return (
    <View style={styles.row} accessibilityRole="adjustable" accessibilityLabel={`Nota ${value ?? 0} de 10`}>
      {STARS.map((star) => (
        <Pressable
          key={star}
          onPress={() => onChange(star * 2)}
          hitSlop={hit.sm}
          accessibilityRole="button"
          accessibilityLabel={`Dar nota ${star * 2}`}
          style={({ pressed }) => pressed && { opacity: opacity.pressed }}
        >
          <Ionicons
            name={star <= filledStars ? 'star' : 'star-outline'}
            size={size}
            color={star <= filledStars ? colors.rating : colors.textTertiary}
          />
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', gap: space.sm },
});
