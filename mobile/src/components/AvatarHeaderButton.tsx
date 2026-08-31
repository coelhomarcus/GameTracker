import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import type { RootStackParamList } from '../navigation/types';
import { useAuthStore } from '../store/authStore';
import { colors } from '../theme/colors';

export function AvatarHeaderButton() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const user = useAuthStore((state) => state.user);

  return (
    <Pressable onPress={() => navigation.navigate('Profile')} style={styles.button} hitSlop={8}>
      {user?.avatarUrl ? (
        <Image source={{ uri: user.avatarUrl }} style={styles.avatarImage} />
      ) : (
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>{user?.username?.[0]?.toUpperCase() ?? '?'}</Text>
        </View>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: { marginLeft: 16, marginRight: 12 },
  avatar: {
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: { color: '#fff', fontWeight: '700', fontSize: 12 },
  avatarImage: { width: 30, height: 30, borderRadius: 15 },
});
