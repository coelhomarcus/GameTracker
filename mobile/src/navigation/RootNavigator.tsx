import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
import AuthNavigator from './AuthNavigator';
import MainTabs from './MainTabs';
import ChatRoomScreen from '../screens/ChatRoomScreen';
import CreatePostScreen from '../screens/CreatePostScreen';
import GameFocusScreen from '../screens/GameFocusScreen';
import NotificationsScreen from '../screens/NotificationsScreen';
import PostDetailScreen from '../screens/PostDetailScreen';
import TrackingFormScreen from '../screens/TrackingFormScreen';
import UserProfileScreen from '../screens/UserProfileScreen';
import { useAuthBootstrap } from '../hooks/useAuthBootstrap';
import { usePushRegistration } from '../hooks/usePushRegistration';
import { useSocketConnection } from '../hooks/useSocketConnection';
import { useAuthStore } from '../store/authStore';
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
    <NavigationContainer>
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
          <Stack.Screen name="Notifications" component={NotificationsScreen} options={{ title: 'Notificações' }} />
          <Stack.Screen name="PostDetail" component={PostDetailScreen} options={{ title: 'Post' }} />
          <Stack.Screen
            name="ChatRoom"
            component={ChatRoomScreen}
            options={({ route }) => ({ title: route.params.otherUsername })}
          />
        </Stack.Navigator>
      ) : (
        <AuthNavigator />
      )}
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  loading: { flex: 1, alignItems: 'center', justifyContent: 'center' },
});
