import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { STATUS_COLOR } from '../lib/gameEntryLabels';
import { colors } from '../theme/colors';
import type { GameEntry } from '../types/models';

interface Props {
  entry: GameEntry;
  width: number;
  onPress: () => void;
}

export function GameEntryGridCell({ entry, width, onPress }: Props) {
  const height = width * (4 / 3);
  return (
    <Pressable style={[styles.card, { width }]} onPress={onPress}>
      <View>
        {entry.game.coverUrl ? (
          <Image source={{ uri: entry.game.coverUrl }} style={[styles.cover, { width, height }]} />
        ) : (
          <View style={[styles.cover, styles.coverPlaceholder, { width, height }]} />
        )}
        <View style={[styles.statusDot, { backgroundColor: STATUS_COLOR[entry.status] }]} />
      </View>
      <Text style={styles.title} numberOfLines={1}>
        {entry.game.name}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { gap: 4 },
  cover: { borderRadius: 6 },
  coverPlaceholder: { backgroundColor: colors.backgroundElevated },
  statusDot: {
    position: 'absolute',
    top: 4,
    right: 4,
    width: 8,
    height: 8,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: colors.background,
  },
  title: { fontSize: 10, color: colors.textPrimary },
});
