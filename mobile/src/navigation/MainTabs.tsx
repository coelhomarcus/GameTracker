import { Ionicons } from '@expo/vector-icons';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { StyleSheet, View } from 'react-native';
import { AvatarHeaderButton } from '../components/AvatarHeaderButton';
import { useNotifications } from '../hooks/queries/useNotifications';
import ConversationsScreen from '../screens/ConversationsScreen';
import FeedScreen from '../screens/FeedScreen';
import MyGamesScreen from '../screens/MyGamesScreen';
import NotificationsScreen from '../screens/NotificationsScreen';
import SearchScreen from '../screens/SearchScreen';
import { colors, radius } from '../theme';
import type { MainTabParamList } from './types';

const Tab = createBottomTabNavigator<MainTabParamList>();

const ICONS: Record<
  keyof MainTabParamList,
  { outline: keyof typeof Ionicons.glyphMap; filled: keyof typeof Ionicons.glyphMap }
> = {
  Feed: { outline: 'home-outline', filled: 'home' },
  Search: { outline: 'search-outline', filled: 'search' },
  MyGames: { outline: 'game-controller-outline', filled: 'game-controller' },
  Chat: { outline: 'chatbubbles-outline', filled: 'chatbubbles' },
  Notifications: { outline: 'notifications-outline', filled: 'notifications' },
};

function NotificationsTabIcon({ color, size, focused }: { color: string; size: number; focused: boolean }) {
  const { unreadCount } = useNotifications();

  return (
    <View>
      <Ionicons name={focused ? ICONS.Notifications.filled : ICONS.Notifications.outline} size={size} color={color} />
      {unreadCount > 0 && <View style={styles.badge} />}
    </View>
  );
}

export default function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarIcon: ({ color, size, focused }) => {
          if (route.name === 'Notifications') {
            return <NotificationsTabIcon color={color} size={size} focused={focused} />;
          }
          const icons = ICONS[route.name as keyof MainTabParamList];
          return <Ionicons name={focused ? icons.filled : icons.outline} size={size} color={color} />;
        },
        tabBarActiveTintColor: colors.textPrimary,
        tabBarInactiveTintColor: colors.textSecondary,
        tabBarStyle: { backgroundColor: colors.background, borderTopColor: colors.border },
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
      <Tab.Screen
        name="Notifications"
        component={NotificationsScreen}
        options={{ title: 'Notificações', headerShown: true, headerLeft: () => <AvatarHeaderButton /> }}
      />
    </Tab.Navigator>
  );
}

const styles = StyleSheet.create({
  badge: {
    position: 'absolute',
    top: -2,
    right: -4,
    width: 8,
    height: 8,
    borderRadius: radius.pill,
    backgroundColor: colors.like,
  },
});
