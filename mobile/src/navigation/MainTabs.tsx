import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import FeedScreen from '../screens/FeedScreen';
import SearchScreen from '../screens/SearchScreen';
import MyGamesScreen from '../screens/MyGamesScreen';
import ConversationsScreen from '../screens/ConversationsScreen';
import ProfileScreen from '../screens/ProfileScreen';
import type { MainTabParamList } from './types';

const Tab = createBottomTabNavigator<MainTabParamList>();

export default function MainTabs() {
  return (
    <Tab.Navigator screenOptions={{ headerShown: false }}>
      <Tab.Screen name="Feed" component={FeedScreen} />
      <Tab.Screen name="Search" component={SearchScreen} options={{ title: 'Busca', headerShown: true }} />
      <Tab.Screen name="MyGames" component={MyGamesScreen} options={{ title: 'Meus jogos', headerShown: true }} />
      <Tab.Screen name="Chat" component={ConversationsScreen} options={{ title: 'Chat', headerShown: true }} />
      <Tab.Screen name="Profile" component={ProfileScreen} options={{ title: 'Perfil', headerShown: true }} />
    </Tab.Navigator>
  );
}
