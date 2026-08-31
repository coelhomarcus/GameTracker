import { Ionicons } from '@expo/vector-icons';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { ActivityIndicator, Pressable, StyleSheet, View } from 'react-native';
import AuthNavigator from './AuthNavigator';
import MainTabs from './MainTabs';
import ChatRoomScreen from '../screens/ChatRoomScreen';
import CreatePostScreen from '../screens/CreatePostScreen';
import GameFocusScreen from '../screens/GameFocusScreen';
import PostDetailScreen from '../screens/PostDetailScreen';
import ProfileScreen from '../screens/ProfileScreen';
import SettingsScreen from '../screens/SettingsScreen';
import TrackingFormScreen from '../screens/TrackingFormScreen';
import UserProfileScreen from '../screens/UserProfileScreen';
import { useAuthBootstrap } from '../hooks/useAuthBootstrap';
import { usePushRegistration } from '../hooks/usePushRegistration';
import { useSocketConnection } from '../hooks/useSocketConnection';
import { useAuthStore } from '../store/authStore';
import { colors } from '../theme/colors';
import { navigationTheme } from '../theme/navigationTheme';
import type { RootStackParamList } from './types';

const Stack = createNativeStackNavigator<RootStackParamList>();

export default function RootNavigator() {
  useAuthBootstrap();
  const isHydrating = useAuthStore((state) => state.isHydrating);
  const isAuthenticated = useAuthStore((state) => state.user !== null);
  usePushRegistration(isAuthenticated);
  useSocketConnection(isAuthenticated);

  if (isHydrating) {
    return (
      <View style={styles.loading}>
        <ActivityIndicator size="large" />
      </View>
    );
  }

  return (
    <NavigationContainer theme={navigationTheme}>
      {isAuthenticated ? (
        <Stack.Navigator>
          <Stack.Screen name="MainTabs" component={MainTabs} options={{ headerShown: false }} />
          <Stack.Screen name="GameFocus" component={GameFocusScreen} options={{ title: 'Jogo' }} />
          <Stack.Screen
            name="TrackingForm"
            component={TrackingFormScreen}
            options={{ title: 'Tracking', presentation: 'modal' }}
          />
          <Stack.Screen name="CreatePost" component={CreatePostScreen} options={{ title: 'Novo post' }} />
          <Stack.Screen name="UserProfile" component={UserProfileScreen} options={{ title: 'Perfil' }} />
          <Stack.Screen
            name="Profile"
            component={ProfileScreen}
            options={({ navigation }) => ({
              title: 'Perfil',
              headerRight: () => (
                <Pressable onPress={() => navigation.navigate('Settings')} hitSlop={8} style={styles.settingsButton}>
                  <Ionicons name="settings-outline" size={22} color={colors.textPrimary} />
                </Pressable>
              ),
            })}
          />
          <Stack.Screen name="Settings" component={SettingsScreen} options={{ title: 'Configurações' }} />
          <Stack.Screen name="PostDetail" component={PostDetailScreen} options={{ title: 'Post' }} />
          <Stack.Screen name="ChatRoom" component={ChatRoomScreen} />
        </Stack.Navigator>
      ) : (
        <AuthNavigator />
      )}
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  loading: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  settingsButton: { marginLeft: 12, marginRight: 16 },
});
