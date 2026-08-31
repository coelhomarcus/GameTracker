import { Ionicons } from '@expo/vector-icons';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { useQuery } from '@tanstack/react-query';
import { View } from 'react-native';
import * as notificationsApi from '../api/notifications';
import { AvatarHeaderButton } from '../components/AvatarHeaderButton';
import { colors } from '../theme/colors';
import FeedScreen from '../screens/FeedScreen';
import SearchScreen from '../screens/SearchScreen';
import MyGamesScreen from '../screens/MyGamesScreen';
import ConversationsScreen from '../screens/ConversationsScreen';
import NotificationsScreen from '../screens/NotificationsScreen';
import type { MainTabParamList } from './types';

const Tab = createBottomTabNavigator<MainTabParamList>();

const ICONS: Record<keyof MainTabParamList, { outline: keyof typeof Ionicons.glyphMap; filled: keyof typeof Ionicons.glyphMap }> = {
  Feed: { outline: 'home-outline', filled: 'home' },
  Search: { outline: 'search-outline', filled: 'search' },
  MyGames: { outline: 'game-controller-outline', filled: 'game-controller' },
  Chat: { outline: 'chatbubbles-outline', filled: 'chatbubbles' },
  Notifications: { outline: 'notifications-outline', filled: 'notifications' },
};

function NotificationsTabIcon({ color, size, focused }: { color: string; size: number; focused: boolean }) {
  const query = useQuery({
    queryKey: ['notifications'],
    queryFn: notificationsApi.listNotifications,
    refetchInterval: 30_000,
  });

  return (
    <View>
      <Ionicons name={focused ? ICONS.Notifications.filled : ICONS.Notifications.outline} size={size} color={color} />
      {!!query.data?.unreadCount && <View style={{ position: 'absolute', top: -2, right: -4, width: 8, height: 8, borderRadius: 4, backgroundColor: colors.like }} />}
    </View>
  );
}

export default function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarIcon: ({ color, size, focused }) => {
          if (route.name === 'Notifications') return <NotificationsTabIcon color={color} size={size} focused={focused} />;
          const icons = ICONS[route.name as keyof MainTabParamList];
          return <Ionicons name={focused ? icons.filled : icons.outline} size={size} color={color} />;
        },
        tabBarActiveTintColor: colors.textPrimary,
        tabBarInactiveTintColor: colors.textSecondary,
        tabBarStyle: { backgroundColor: colors.background, borderTopColor: colors.border },
        headerStyle: { backgroundColor: colors.background },
        headerTintColor: colors.textPrimary,
      })}
    >
      <Tab.Screen name="Feed" component={FeedScreen} />
      <Tab.Screen
        name="Search"
        component={SearchScreen}
        options={{ title: 'Busca', headerShown: true, headerLeft: () => <AvatarHeaderButton /> }}
      />
      <Tab.Screen
        name="MyGames"
        component={MyGamesScreen}
        options={{ title: 'Meus jogos', headerShown: true, headerLeft: () => <AvatarHeaderButton /> }}
      />
      <Tab.Screen
        name="Chat"
        component={ConversationsScreen}
        options={{ title: 'Chat', headerShown: true, headerLeft: () => <AvatarHeaderButton /> }}
      />
      <Tab.Screen name="Notifications" component={NotificationsScreen} options={{ title: 'Notificações', headerShown: true }} />
    </Tab.Navigator>
  );
}
