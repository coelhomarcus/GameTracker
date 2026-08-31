import { Ionicons } from '@expo/vector-icons';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { StyleSheet, View } from 'react-native';
import { Avatar } from '../components/ui';
import { AvatarHeaderButton } from '../components/AvatarHeaderButton';
import { NotificationsHeaderButton } from '../components/NotificationsHeaderButton';
import ConversationsScreen from '../screens/ConversationsScreen';
import FeedScreen from '../screens/FeedScreen';
import MyGamesScreen from '../screens/MyGamesScreen';
import SearchScreen from '../screens/SearchScreen';
import { useAuthStore } from '../store/authStore';
import { colors, space } from '../theme';
import type { MainTabParamList, RootStackParamList } from './types';

const Tab = createBottomTabNavigator<MainTabParamList>();

const ICONS: Record<
  Exclude<keyof MainTabParamList, 'ProfileTab'>,
  { outline: keyof typeof Ionicons.glyphMap; filled: keyof typeof Ionicons.glyphMap }
> = {
  Feed: { outline: 'home-outline', filled: 'home' },
  Search: { outline: 'search-outline', filled: 'search' },
  MyGames: { outline: 'game-controller-outline', filled: 'game-controller' },
  Chat: { outline: 'chatbubbles-outline', filled: 'chatbubbles' },
};

/** Nunca é o ícone "ativo" de verdade — o tabPress é interceptado antes de
 *  trocar de aba, então o app sempre continua na aba anterior. */
function ProfileTabIcon() {
  const user = useAuthStore((state) => state.user);
  return <Avatar user={user} size="xs" />;
}

/** Componente nunca chega a renderizar — o tabPress abaixo sempre intercepta antes. */
function ProfileTabStub() {
  return <View />;
}

export default function MainTabs() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();

  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarIcon: ({ color, size, focused }) => {
          if (route.name === 'ProfileTab') return <ProfileTabIcon />;
          const icons = ICONS[route.name as Exclude<keyof MainTabParamList, 'ProfileTab'>];
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
        options={{
          title: 'Busca',
          headerShown: true,
          headerLeft: () => <AvatarHeaderButton />,
          headerRight: () => <NotificationsHeaderButton style={styles.headerRight} />,
        }}
      />
      <Tab.Screen
        name="MyGames"
        component={MyGamesScreen}
        options={{
          title: 'Meus jogos',
          headerShown: true,
          headerLeft: () => <AvatarHeaderButton />,
          headerRight: () => <NotificationsHeaderButton style={styles.headerRight} />,
        }}
      />
      <Tab.Screen
        name="Chat"
        component={ConversationsScreen}
        options={{
          title: 'Chat',
          headerShown: true,
          headerLeft: () => <AvatarHeaderButton />,
          headerRight: () => <NotificationsHeaderButton style={styles.headerRight} />,
        }}
      />
      <Tab.Screen
        name="ProfileTab"
        component={ProfileTabStub}
        options={{ tabBarAccessibilityLabel: 'Abrir meu perfil' }}
        listeners={{
          tabPress: (e) => {
            e.preventDefault();
            navigation.navigate('Profile');
          },
        }}
      />
    </Tab.Navigator>
  );
}

const styles = StyleSheet.create({
  // Espelha o marginLeft/marginRight do AvatarHeaderButton, do outro lado do header.
  headerRight: { marginLeft: space.md, marginRight: space.lg },
});
