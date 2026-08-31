import { StyleSheet, Text, View, type StyleProp, type ViewStyle } from 'react-native';
import { STATUS_COLOR, STATUS_LABEL } from '../../lib/gameEntryLabels';
import { colors, radius, space, type } from '../../theme';
import type { GameEntryStatus } from '../../types/models';

interface Props {
  status: GameEntryStatus;
  /** `dot` é a marca sobre a capa no grid. */
  variant?: 'badge' | 'dot';
  style?: StyleProp<ViewStyle>;
}

export function StatusBadge({ status, variant = 'badge', style }: Props) {
  const color = STATUS_COLOR[status];

  if (variant === 'dot') {
    return (
      <View
        style={[styles.dot, { backgroundColor: color }, style]}
        accessibilityLabel={STATUS_LABEL[status]}
      />
    );
  }

  return (
    <View style={[styles.badge, { backgroundColor: `${color}22`, borderColor: `${color}55` }, style]}>
      <Text style={[styles.label, { color }]}>{STATUS_LABEL[status]}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    alignSelf: 'flex-start',
    borderRadius: radius.pill,
    borderWidth: 1,
    paddingVertical: space.xs,
    paddingHorizontal: space.md,
  },
  label: type.micro,
  dot: {
    position: 'absolute',
    top: space.xs,
    right: space.xs,
    width: 8,
    height: 8,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.background,
  },
});
