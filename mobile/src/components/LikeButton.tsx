import { Ionicons } from '@expo/vector-icons';
import { useRef } from 'react';
import { Animated, Pressable, StyleSheet, Text } from 'react-native';
import { colors, hit, icon as iconScale, opacity, space, type } from '../theme';

interface Props {
  liked: boolean;
  count: number;
  size?: number;
  onPress: () => void;
}

export function LikeButton({ liked, count, size = iconScale.md, onPress }: Props) {
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
    <Pressable
      style={({ pressed }) => [styles.button, pressed && { opacity: opacity.pressed }]}
      onPress={handlePress}
      hitSlop={hit.md}
      accessibilityRole="button"
      accessibilityLabel={liked ? 'Descurtir' : 'Curtir'}
      accessibilityState={{ selected: liked }}
    >
      <Animated.View style={{ transform: [{ scale }] }}>
        <Ionicons
          name={liked ? 'heart' : 'heart-outline'}
          size={size}
          color={liked ? colors.like : colors.textSecondary}
        />
      </Animated.View>
      {count > 0 && <Text style={[styles.text, liked && styles.textActive]}>{count}</Text>}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: { flexDirection: 'row', alignItems: 'center', gap: space.xs },
  // Contagem em mono: é dado, e alinha entre linhas da lista.
  text: { ...type.dataSm, color: colors.textSecondary },
  textActive: { color: colors.like },
});
