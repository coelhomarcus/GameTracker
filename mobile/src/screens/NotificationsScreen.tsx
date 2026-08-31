import { Ionicons } from '@expo/vector-icons';
import { useFocusEffect, useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback, useState } from 'react';
import { FlatList, Pressable, StyleSheet, Text, View } from 'react-native';
import * as notificationsApi from '../api/notifications';
import { EmptyState } from '../components/EmptyState';
import { LoadingState } from '../components/LoadingState';
import { displayName } from '../lib/displayName';
import type { RootStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';
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

type FilterTab = 'all' | 'interactions' | 'followers';

const TABS: { value: FilterTab; label: string }[] = [
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
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<FilterTab>('all');

  const query = useQuery({
    queryKey: ['notifications'],
    queryFn: notificationsApi.listNotifications,
  });

  const markReadMutation = useMutation({
    mutationFn: notificationsApi.markAllRead,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['notifications'] }),
  });

  useFocusEffect(
    useCallback(() => {
      if (query.data && query.data.unreadCount > 0) markReadMutation.mutate();
    }, [query.data]),
  );

  const items = (query.data?.items ?? []).filter((item) => matchesTab(item.type, tab));

  function renderItem({ item }: { item: AppNotification }) {
    return (
      <Pressable
        style={[styles.row, !item.read && styles.rowUnread]}
        onPress={() =>
          item.postId
            ? navigation.navigate('PostDetail', { postId: item.postId })
            : navigation.navigate('UserProfile', { userId: item.actorId })
        }
      >
        <Ionicons name={ICON[item.type]} size={18} color={colors.accent} />
        <Text style={styles.text}>{MESSAGE[item.type](displayName(item.actor))}</Text>
      </Pressable>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.tabs}>
        {TABS.map((t) => (
          <Pressable key={t.value} style={styles.tab} onPress={() => setTab(t.value)}>
            <Text style={[styles.tabText, tab === t.value && styles.tabTextActive]}>{t.label}</Text>
            {tab === t.value && <View style={styles.tabIndicator} />}
          </Pressable>
        ))}
      </View>

      <FlatList
        data={items}
        keyExtractor={(item) => item.id}
        renderItem={renderItem}
        ListEmptyComponent={
          query.isLoading ? (
            <LoadingState />
          ) : (
            <EmptyState icon="notifications-outline" title="Nenhuma notificação ainda" />
          )
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  tabs: { flexDirection: 'row', borderBottomWidth: 1, borderBottomColor: colors.border },
  tab: { flex: 1, alignItems: 'center', paddingVertical: 12 },
  tabText: { color: colors.textSecondary, fontWeight: '600', fontSize: 13 },
  tabTextActive: { color: colors.textPrimary },
  tabIndicator: { position: 'absolute', bottom: 0, height: 2, width: '50%', backgroundColor: colors.accent, borderRadius: 1 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 16, borderBottomWidth: 1, borderBottomColor: colors.border },
  rowUnread: { backgroundColor: colors.surface },
  text: { flex: 1, fontSize: 14, color: colors.textPrimary },
});
