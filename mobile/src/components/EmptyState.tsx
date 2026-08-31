import { Ionicons } from '@expo/vector-icons';
import { StyleSheet, Text, View } from 'react-native';
import { colors, icon, radius, space, type } from '../theme';

interface Props {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  subtitle?: string;
}

export function EmptyState({ icon: iconName, title, subtitle }: Props) {
  return (
    <View style={styles.container}>
      <View style={styles.iconCircle}>
        <Ionicons name={iconName} size={icon.hero} color={colors.textSecondary} />
      </View>
      <Text style={styles.title}>{title}</Text>
      {subtitle && <Text style={styles.subtitle}>{subtitle}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: space.huge,
    paddingHorizontal: space.xxl,
    gap: space.sm,
  },
  iconCircle: {
    width: 56,
    height: 56,
    borderRadius: radius.pill,
    backgroundColor: colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: space.xs,
  },
  title: { ...type.bodyStrong, color: colors.textPrimary, textAlign: 'center' },
  subtitle: { ...type.caption, color: colors.textSecondary, textAlign: 'center' },
});
