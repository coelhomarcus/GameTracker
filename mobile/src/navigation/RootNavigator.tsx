import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { StyleSheet } from 'react-native';
import { LoadingState } from '../components/LoadingState';
import { IconButton } from '../components/ui';
import { useAuthBootstrap } from '../hooks/useAuthBootstrap';
import { usePushRegistration } from '../hooks/usePushRegistration';
import { useSocketConnection } from '../hooks/useSocketConnection';
import ChatRoomScreen from '../screens/ChatRoomScreen';
import CreatePostScreen from '../screens/CreatePostScreen';
import EditProfileScreen from '../screens/EditProfileScreen';
import GameFocusScreen from '../screens/GameFocusScreen';
import PostDetailScreen from '../screens/PostDetailScreen';
import ProfileScreen from '../screens/ProfileScreen';
import SettingsScreen from '../screens/SettingsScreen';
import TrackingFormScreen from '../screens/TrackingFormScreen';
import UserProfileScreen from '../screens/UserProfileScreen';
import { useAuthStore } from '../store/authStore';
import { navigationTheme } from '../theme/navigationTheme';
import { colors, space } from '../theme';
import AuthNavigator from './AuthNavigator';
import MainTabs from './MainTabs';
import type { RootStackParamList } from './types';

const Stack = createNativeStackNavigator<RootStackParamList>();

export default function RootNavigator() {
  useAuthBootstrap();
  const isHydrating = useAuthStore((state) => state.isHydrating);
  const isAuthenticated = useAuthStore((state) => state.user !== null);
  usePushRegistration(isAuthenticated);
  useSocketConnection(isAuthenticated);

  if (isHydrating) return <LoadingState fullScreen />;

  return (
    <NavigationContainer theme={navigationTheme}>
      {isAuthenticated ? (
        // headerStyle/headerTintColor vêm do navigationTheme; repetir aqui só
        // criaria dois lugares para divergir.
        <Stack.Navigator>
          <Stack.Screen name="MainTabs" component={MainTabs} options={{ headerShown: false }} />
          <Stack.Screen name="GameFocus" component={GameFocusScreen} options={{ title: 'Jogo' }} />
          <Stack.Screen
            name="TrackingForm"
            component={TrackingFormScreen}
            options={{ title: 'Playthrough', presentation: 'modal' }}
          />
          <Stack.Screen name="CreatePost" component={CreatePostScreen} options={{ title: 'Novo post' }} />
          <Stack.Screen name="UserProfile" component={UserProfileScreen} options={{ title: 'Perfil' }} />
          <Stack.Screen
            name="Profile"
            component={ProfileScreen}
            options={({ navigation }) => ({
              title: 'Perfil',
              headerRight: () => (
                <IconButton
                  name="settings-outline"
                  size="xl"
                  color={colors.textPrimary}
                  onPress={() => navigation.navigate('Settings')}
                  accessibilityLabel="Configurações"
                  style={styles.headerRight}
                />
              ),
            })}
          />
          <Stack.Screen
            name="EditProfile"
            component={EditProfileScreen}
            options={{ title: 'Editar perfil', presentation: 'modal' }}
          />
          <Stack.Screen name="Settings" component={SettingsScreen} options={{ title: 'Configurações' }} />
          <Stack.Screen name="PostDetail" component={PostDetailScreen} options={{ title: 'Post' }} />
          {/* Título real vem do próprio ChatRoom; este é o fallback do 1º frame. */}
          <Stack.Screen name="ChatRoom" component={ChatRoomScreen} options={{ title: 'Conversa' }} />
        </Stack.Navigator>
      ) : (
        <AuthNavigator />
      )}
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  headerRight: { marginRight: space.sm },
});
