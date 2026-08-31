import { Ionicons } from '@expo/vector-icons';
import { Pressable, StyleSheet, View } from 'react-native';

interface Props {
  value: number | null;
  onChange: (value: number) => void;
  size?: number;
}

const STARS = [1, 2, 3, 4, 5];

export function StarRating({ value, onChange, size = 36 }: Props) {
  const filledStars = value ? Math.round(value / 2) : 0;

  return (
    <View style={styles.row}>
      {STARS.map((star) => (
        <Pressable key={star} onPress={() => onChange(star * 2)} hitSlop={8}>
          <Ionicons name={star <= filledStars ? 'star' : 'star-outline'} size={size} color="#f59e0b" />
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', gap: 8 },
});
