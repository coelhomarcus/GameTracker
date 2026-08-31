import { Ionicons } from '@expo/vector-icons';
import { useFocusEffect, useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useCallback, useRef, useState } from 'react';
import { FlatList, Pressable, RefreshControl, StyleSheet, Text } from 'react-native';
import { Avatar, ListState, Screen, SegmentedTabs, type Tab } from '../components/ui';
import { useMarkNotificationsRead, useNotifications } from '../hooks/queries/useNotifications';
import { displayName } from '../lib/displayName';
import type { RootStackParamList } from '../navigation/types';
import { colors, icon, space, type } from '../theme';
import type { AppNotification, NotificationType } from '../types/models';

const MESSAGE: Record<NotificationType, (name: string) => string> = {
  like: (name) => `${name} curtiu seu post`,
  comment: (name) => `${name} comentou no seu post`,
  follow: (name) => `${name} começou a seguir você`,
};

const ICON: Record<NotificationType, keyof typeof Ionicons.glyphMap> = {
  like: 'heart',
  comment: 'chatbubble',
  follow: 'person-add',
};

const ICON_COLOR: Record<NotificationType, string> = {
  like: colors.like,
  comment: colors.accent,
  follow: colors.success,
};

type FilterTab = 'all' | 'interactions' | 'followers';

const TABS: readonly Tab<FilterTab>[] = [
  { value: 'all', label: 'Tudo' },
  { value: 'interactions', label: 'Interações' },
  { value: 'followers', label: 'Seguidores' },
];

function matchesTab(type: NotificationType, tab: FilterTab) {
  if (tab === 'all') return true;
  if (tab === 'interactions') return type === 'like' || type === 'comment';
  return type === 'follow';
}

export default function NotificationsScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const [tab, setTab] = useState<FilterTab>('all');

  const query = useNotifications();
  const markRead = useMarkNotificationsRead();

  /**
   * O destaque de não-lida é desenhado a partir de um retrato tirado ao entrar
   * na tela, e a marcação acontece ao sair. Antes marcava-se tudo como lido no
   * foco, o que apagava o destaque antes do usuário conseguir ver qual era nova.
   */
  const unreadSnapshot = useRef<Set<string>>(new Set());
  // Ref em vez de dependência: `items` é um array novo a cada render, e como
  // dep faria o efeito de foco (e o mark-read do cleanup) rodar em loop.
  const itemsRef = useRef(query.items);
  itemsRef.current = query.items;

  const markReadMutate = markRead.mutate;

  useFocusEffect(
    useCallback(() => {
      unreadSnapshot.current = new Set(
        itemsRef.current.filter((notification) => !notification.read).map((notification) => notification.id),
      );

      return () => {
        // Lê o estado no momento da saída: no foco os dados podem nem ter
        // chegado ainda.
        if (itemsRef.current.some((notification) => !notification.read)) markReadMutate();
      };
    }, [markReadMutate]),
  );

  const items = query.items.filter((item) => matchesTab(item.type, tab));

  const renderItem = useCallback(
    ({ item }: { item: AppNotification }) => {
      const unread = !item.read || unreadSnapshot.current.has(item.id);
      const message = MESSAGE[item.type](displayName(item.actor));

      return (
        <Pressable
          style={({ pressed }) => [styles.row, unread && styles.rowUnread, pressed && styles.rowPressed]}
          accessibilityRole="button"
          accessibilityLabel={unread ? `Nova: ${message}` : message}
          onPress={() =>
            item.postId
              ? navigation.navigate('PostDetail', { postId: item.postId })
              : navigation.navigate('UserProfile', { userId: item.actorId })
          }
        >
          <Avatar user={item.actor} size="md" />
          <Ionicons name={ICON[item.type]} size={icon.md} color={ICON_COLOR[item.type]} />
          <Text style={styles.text}>{message}</Text>
        </Pressable>
      );
    },
    [navigation],
  );

  return (
    <Screen>
      <SegmentedTabs tabs={TABS} value={tab} onChange={setTab} />

      <FlatList
        data={items}
        keyExtractor={(item) => item.id}
        renderItem={renderItem}
        refreshControl={<RefreshControl refreshing={query.isRefetching} onRefresh={() => query.refetch()} />}
        keyboardShouldPersistTaps="handled"
        ListEmptyComponent={
          <ListState
            query={query}
            empty={{
              icon: 'notifications-outline',
              title: 'Nenhuma notificação ainda',
              subtitle: 'Curtidas, comentários e novos seguidores aparecem aqui',
            }}
          />
        }
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: space.md,
    padding: space.lg,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  rowUnread: { backgroundColor: colors.surface },
  rowPressed: { backgroundColor: colors.surfaceRaised },
  text: { ...type.body, flex: 1, color: colors.textPrimary },
});
