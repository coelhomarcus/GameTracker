import { Ionicons } from '@expo/vector-icons';
import { useState } from 'react';
import { Alert, Pressable, StyleSheet, Text, View } from 'react-native';
import * as authApi from '../api/auth';
import { Screen } from '../components/ui';
import { clearSessionEverywhere } from '../lib/session';
import { useAuthStore } from '../store/authStore';
import { colors, icon, opacity, space, type } from '../theme';

export default function SettingsScreen() {
  const refreshToken = useAuthStore((state) => state.refreshToken);
  const [leaving, setLeaving] = useState(false);

  async function handleLogout() {
    setLeaving(true);
    try {
      if (refreshToken) await authApi.logout(refreshToken);
    } catch {
      // Servidor fora do ar não pode prender o usuário na conta: a sessão local
      // é limpa de qualquer jeito no finally.
    } finally {
      await clearSessionEverywhere();
    }
  }

  function confirmLogout() {
    Alert.alert('Sair da conta', 'Você vai precisar entrar de novo.', [
      { text: 'Cancelar', style: 'cancel' },
      { text: 'Sair', style: 'destructive', onPress: handleLogout },
    ]);
  }

  return (
    <Screen>
      <View style={styles.section}>
        <Pressable
          style={({ pressed }) => [styles.row, pressed && { opacity: opacity.pressed }]}
          onPress={confirmLogout}
          disabled={leaving}
          accessibilityRole="button"
          accessibilityLabel="Sair da conta"
        >
          <Ionicons name="log-out-outline" size={icon.lg} color={colors.danger} />
          <Text style={styles.rowTextDanger}>Sair da conta</Text>
        </Pressable>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  section: {
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderColor: colors.border,
    marginTop: space.lg,
  },
  row: { flexDirection: 'row', alignItems: 'center', gap: space.md, padding: space.lg },
  rowTextDanger: { ...type.bodyStrong, color: colors.danger },
});
