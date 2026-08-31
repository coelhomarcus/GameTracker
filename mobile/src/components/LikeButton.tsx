import { Ionicons } from '@expo/vector-icons';
import { useRef } from 'react';
import { Animated, Pressable, StyleSheet, Text } from 'react-native';
import { colors } from '../theme/colors';

interface Props {
  liked: boolean;
  count: number;
  size?: number;
  onPress: () => void;
}

export function LikeButton({ liked, count, size = 18, onPress }: Props) {
  const scale = useRef(new Animated.Value(1)).current;

  function handlePress() {
    if (!liked) {
      scale.setValue(0.7);
      Animated.spring(scale, {
        toValue: 1,
        friction: 3,
        tension: 250,
        useNativeDriver: true,
      }).start();
    }
    onPress();
  }

  return (
    <Pressable style={styles.button} onPress={handlePress} hitSlop={6}>
      <Animated.View style={{ transform: [{ scale }] }}>
        <Ionicons name={liked ? 'heart' : 'heart-outline'} size={size} color={liked ? colors.like : colors.textSecondary} />
      </Animated.View>
      {count > 0 && <Text style={[styles.text, liked && styles.textActive]}>{count}</Text>}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  text: { color: colors.textSecondary, fontSize: 13 },
  textActive: { color: colors.like },
});
