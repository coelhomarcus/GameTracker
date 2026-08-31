import { StyleSheet, View } from 'react-native';
import { getApiErrorMessage } from '../../lib/apiError';
import { space } from '../../theme';
import { EmptyState } from '../EmptyState';
import { Button } from './Button';

interface Props {
  error: unknown;
  onRetry: () => void;
  title?: string;
}

export function ErrorState({ error, onRetry, title = 'Não foi possível carregar' }: Props) {
  return (
    <View style={styles.container}>
      <EmptyState icon="cloud-offline-outline" title={title} subtitle={getApiErrorMessage(error)} />
      <Button label="Tentar de novo" onPress={onRetry} variant="secondary" size="sm" />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { alignItems: 'center', gap: space.lg },
});
