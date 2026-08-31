import { ActivityIndicator, StyleSheet, View } from 'react-native';
import { colors, space } from '../../theme';

interface Props {
  loading: boolean;
}

export function ListFooter({ loading }: Props) {
  if (!loading) return null;
  return (
    <View style={styles.container}>
      <ActivityIndicator color={colors.accent} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { paddingVertical: space.xl, alignItems: 'center' },
});
