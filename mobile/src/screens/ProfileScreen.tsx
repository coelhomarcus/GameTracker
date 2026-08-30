import { Pressable, StyleSheet, Text, View } from 'react-native';
import * as authApi from '../api/auth';
import { clearSessionEverywhere } from '../lib/session';
import { useAuthStore } from '../store/authStore';

export default function ProfileScreen() {
  const user = useAuthStore((state) => state.user);
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
      <View style={styles.avatar}>
        <Text style={styles.avatarText}>{user?.username?.[0]?.toUpperCase() ?? '?'}</Text>
      </View>
      <Text style={styles.username}>{user?.username}</Text>
      <Text style={styles.email}>{user?.email}</Text>

      <Pressable style={styles.button} onPress={handleLogout}>
        <Text style={styles.buttonText}>Sair</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24, gap: 4 },
  avatar: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: '#4f46e5',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
  },
  avatarText: { color: '#fff', fontSize: 28, fontWeight: '700' },
  username: { fontSize: 20, fontWeight: '700' },
  email: { color: '#666', marginBottom: 24 },
  button: { borderWidth: 1, borderColor: '#dc2626', borderRadius: 8, paddingVertical: 10, paddingHorizontal: 24 },
  buttonText: { color: '#dc2626', fontWeight: '600' },
});
