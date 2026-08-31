import { ActivityIndicator, StyleSheet, View } from 'react-native';
import { colors, space } from '../theme';

interface Props {
  fullScreen?: boolean;
}

export function LoadingState({ fullScreen }: Props) {
  return (
    <View style={[styles.container, fullScreen && styles.fullScreen]}>
      <ActivityIndicator size="large" color={colors.accent} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { alignItems: 'center', justifyContent: 'center', paddingVertical: space.xxl },
  fullScreen: { flex: 1, backgroundColor: colors.background },
});
