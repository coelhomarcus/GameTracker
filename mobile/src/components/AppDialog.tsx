import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { useDialogStore } from '../store/dialogStore';
import { colors, elevation, radius, space, type } from '../theme';
import { Button } from './ui';

/**
 * Diálogo único do app, montado uma vez em App.tsx. Substitui Alert.alert
 * (UI do SO, e um no-op silencioso na web) e window.alert/confirm (não segue
 * o tema) por um modal próprio, no estilo do resto do app.
 */
export function AppDialog() {
  const { visible, title, message, confirmLabel, cancelLabel, destructive, onConfirm, hide } = useDialogStore();

  function confirm() {
    hide();
    onConfirm?.();
  }

  return (
    <Modal visible={visible} transparent animationType="fade" statusBarTranslucent onRequestClose={hide}>
      <Pressable style={styles.backdrop} onPress={hide} accessibilityRole="none">
        {/* Pressable interno só pra tocar no cartão não fechar o diálogo por trás. */}
        <Pressable style={styles.card} onPress={() => {}}>
          <Text style={styles.title}>{title}</Text>
          {message ? <Text style={styles.message}>{message}</Text> : null}

          <View style={[styles.actions, !cancelLabel && styles.actionsSingle]}>
            {cancelLabel && (
              <Button label={cancelLabel} variant="secondary" size="sm" onPress={hide} style={styles.action} />
            )}
            <Button
              label={confirmLabel}
              variant={destructive ? 'danger' : 'primary'}
              size="sm"
              onPress={confirm}
              style={styles.action}
            />
          </View>
        </Pressable>
      </Pressable>
    </Modal>
  );
}

const CARD_MAX_WIDTH = 360;

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: colors.scrim,
    alignItems: 'center',
    justifyContent: 'center',
    padding: space.xl,
  },
  card: {
    width: '100%',
    maxWidth: CARD_MAX_WIDTH,
    backgroundColor: colors.surfaceRaised,
    borderRadius: radius.xl,
    padding: space.xl,
    gap: space.sm,
    ...elevation.overlay,
  },
  title: { ...type.heading, color: colors.textPrimary },
  message: { ...type.body, color: colors.textSecondary, marginBottom: space.sm },
  actions: { flexDirection: 'row', justifyContent: 'flex-end', gap: space.sm, marginTop: space.sm },
  actionsSingle: { justifyContent: 'flex-end' },
  action: { minWidth: 88 },
});
