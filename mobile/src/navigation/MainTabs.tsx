import { Ionicons } from '@expo/vector-icons';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Pressable } from 'react-native';
import FeedScreen from '../screens/FeedScreen';
import SearchScreen from '../screens/SearchScreen';
import MyGamesScreen from '../screens/MyGamesScreen';
import ConversationsScreen from '../screens/ConversationsScreen';
import ProfileScreen from '../screens/ProfileScreen';
import type { MainTabParamList, RootStackParamList } from './types';

const Tab = createBottomTabNavigator<MainTabParamList>();

const ICONS: Record<keyof MainTabParamList, keyof typeof Ionicons.glyphMap> = {
  Feed: 'home-outline',
  Search: 'search-outline',
  MyGames: 'game-controller-outline',
  Chat: 'chatbubbles-outline',
  Profile: 'person-outline',
};

export default function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarIcon: ({ color, size }) => (
          <Ionicons name={ICONS[route.name as keyof MainTabParamList]} size={size} color={color} />
        ),
        tabBarActiveTintColor: '#4f46e5',
      })}
    >
      <Tab.Screen name="Feed" component={FeedScreen} />
      <Tab.Screen name="Search" component={SearchScreen} options={{ title: 'Busca', headerShown: true }} />
      <Tab.Screen name="MyGames" component={MyGamesScreen} options={{ title: 'Meus jogos', headerShown: true }} />
      <Tab.Screen
        name="Chat"
        component={ConversationsScreen}
        options={({ navigation }) => ({
          title: 'Chat',
          headerShown: true,
          headerRight: () => (
            <Pressable
              onPress={() => (navigation as unknown as NativeStackNavigationProp<RootStackParamList>).navigate('FindUsers')}
              hitSlop={8}
              style={{ marginRight: 12 }}
            >
              <Ionicons name="person-add-outline" size={22} color="#111" />
            </Pressable>
          ),
        })}
      />
      <Tab.Screen name="Profile" component={ProfileScreen} options={{ title: 'Perfil', headerShown: true }} />
    </Tab.Navigator>
  );
}
