import { ActivityIndicator, StyleSheet, View, type ViewStyle } from 'react-native';
import { colors } from '../theme/colors';

interface Props {
  fullScreen?: boolean;
  style?: ViewStyle;
}

export function LoadingState({ fullScreen, style }: Props) {
  return (
    <View style={[styles.container, fullScreen && styles.fullScreen, style]}>
      <ActivityIndicator size="large" color={colors.accent} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { alignItems: 'center', justifyContent: 'center', paddingVertical: 32 },
  fullScreen: { flex: 1, backgroundColor: colors.background },
});
