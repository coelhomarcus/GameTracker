import { Ionicons } from '@expo/vector-icons';
import { Pressable, StyleSheet, View } from 'react-native';

interface Props {
  value: number | null;
  onChange: (value: number) => void;
  size?: number;
}

const STARS = Array.from({ length: 10 }, (_, i) => i + 1);

export function StarRating({ value, onChange, size = 22 }: Props) {
  return (
    <View style={styles.row}>
      {STARS.map((star) => (
        <Pressable key={star} onPress={() => onChange(star)} hitSlop={4}>
          <Ionicons name={value !== null && star <= value ? 'star' : 'star-outline'} size={size} color="#f59e0b" />
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', gap: 2 },
});
