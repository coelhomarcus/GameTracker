import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Pressable, StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';
import { useNotifications } from '../hooks/queries/useNotifications';
import type { RootStackParamList } from '../navigation/types';
import { colors, hit, icon, radius } from '../theme';

interface Props {
  style?: StyleProp<ViewStyle>;
}

/**
 * Sino de notificações — mesmo pontinho de não-lida que a tab bar já usava.
 * Sem margem própria: quem usa como headerRight de tela nativa (MainTabs) ou
 * dentro de uma row com padding próprio (FeedScreen) decide o espaçamento.
 */
export function NotificationsHeaderButton({ style }: Props) {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const { unreadCount } = useNotifications();

  return (
    <Pressable
      onPress={() => navigation.navigate('Notifications')}
      hitSlop={hit.md}
      style={[styles.button, style]}
      accessibilityRole="button"
      accessibilityLabel={unreadCount > 0 ? `Notificações, ${unreadCount} não lidas` : 'Notificações'}
    >
      <Ionicons name="notifications-outline" size={icon.xl} color={colors.textPrimary} />
      {unreadCount > 0 && <View style={styles.badge} />}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {},
  badge: {
    position: 'absolute',
    top: -2,
    right: -2,
    width: 8,
    height: 8,
    borderRadius: radius.pill,
    backgroundColor: colors.like,
  },
});
