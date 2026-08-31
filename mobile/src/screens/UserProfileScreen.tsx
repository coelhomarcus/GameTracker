import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useEffect } from 'react';
import { LoadingState } from '../components/LoadingState';
import { ProfileView } from '../components/profile/ProfileView';
import type { RootStackParamList } from '../navigation/types';
import { useAuthStore } from '../store/authStore';

export default function UserProfileScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'UserProfile'>>();
  const { userId } = route.params;
  const myId = useAuthStore((state) => state.user?.id);
  const isMe = !!myId && userId === myId;

  /**
   * "Meu perfil" é uma rota própria — é ela que tem a engrenagem de
   * configurações no header. Chegando aqui vendo a si mesmo (tocando no próprio
   * nome num post, por exemplo), redireciona pra rota canônica.
   */
  useEffect(() => {
    if (isMe) navigation.replace('Profile');
  }, [isMe, navigation]);

  if (isMe) return <LoadingState fullScreen />;

  return <ProfileView userId={userId} isSelf={false} />;
}
