import { memo } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { STATUS_LABEL } from '../lib/gameEntryLabels';
import { colors, GRID, opacity, radius, space, type } from '../theme';
import type { GameEntry } from '../types/models';
import { RemoteImage, StatusBadge } from './ui';

interface Props {
  entry: GameEntry;
  width: number;
  onPress: () => void;
}

function GameEntryGridCellComponent({ entry, width, onPress }: Props) {
  const height = width * GRID.coverRatio;

  return (
    <Pressable
      style={({ pressed }) => [styles.card, { width }, pressed && { opacity: opacity.pressed }]}
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={`${entry.game.name}, ${STATUS_LABEL[entry.status]}`}
    >
      <View>
        <RemoteImage uri={entry.game.coverUrl} style={[styles.cover, { width, height }]} />
        <StatusBadge status={entry.status} variant="dot" />
      </View>
      <Text style={styles.title} numberOfLines={1}>
        {entry.game.name}
      </Text>
    </Pressable>
  );
}

export const GameEntryGridCell = memo(GameEntryGridCellComponent);

const styles = StyleSheet.create({
  card: { gap: space.xs },
  cover: { borderRadius: radius.sm, backgroundColor: colors.skeleton },
  title: { ...type.micro, color: colors.textPrimary },
});
