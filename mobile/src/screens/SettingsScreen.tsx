import { Ionicons } from '@expo/vector-icons';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import * as authApi from '../api/auth';
import { clearSessionEverywhere } from '../lib/session';
import { useAuthStore } from '../store/authStore';
import { colors } from '../theme/colors';

export default function SettingsScreen() {
  const refreshToken = useAuthStore((state) => state.refreshToken);

  async function handleLogout() {
    try {
      if (refreshToken) await authApi.logout(refreshToken);
    } finally {
      await clearSessionEverywhere();
    }
  }

  return (
    <View style={styles.container}>
      <View style={styles.section}>
        <Pressable style={styles.row} onPress={handleLogout}>
          <Ionicons name="log-out-outline" size={20} color={colors.like} />
          <Text style={styles.rowTextDanger}>Sair da conta</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  section: { borderTopWidth: 1, borderBottomWidth: 1, borderColor: colors.border, marginTop: 16 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 16 },
  rowTextDanger: { color: colors.like, fontSize: 15, fontWeight: '600' },
});
