import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { StyleSheet } from 'react-native';
import type { RootStackParamList } from '../navigation/types';
import { useAuthStore } from '../store/authStore';
import { space } from '../theme';
import { Avatar } from './ui';

export function AvatarHeaderButton() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const user = useAuthStore((state) => state.user);

  return (
    <Avatar
      user={user}
      size="sm"
      onPress={() => navigation.navigate('Profile')}
      accessibilityLabel="Abrir meu perfil"
      style={styles.button}
    />
  );
}

const styles = StyleSheet.create({
  button: { marginLeft: space.lg, marginRight: space.md },
});
