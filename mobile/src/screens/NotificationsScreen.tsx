import { useFocusEffect, useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { FlatList, Pressable, StyleSheet, Text, View } from 'react-native';
import * as notificationsApi from '../api/notifications';
import type { RootStackParamList } from '../navigation/types';
import type { AppNotification, NotificationType } from '../types/models';

const MESSAGE: Record<NotificationType, (username: string) => string> = {
  like: (username) => `${username} curtiu seu post`,
  comment: (username) => `${username} comentou no seu post`,
  follow: (username) => `${username} começou a seguir você`,
};

export default function NotificationsScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const queryClient = useQueryClient();

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
        <Text style={styles.icon}>{item.type === 'like' ? '❤️' : item.type === 'comment' ? '💬' : '👤'}</Text>
        <Text style={styles.text}>{MESSAGE[item.type](item.actor.username)}</Text>
      </Pressable>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={query.data?.items ?? []}
        keyExtractor={(item) => item.id}
        renderItem={renderItem}
        ListEmptyComponent={!query.isLoading ? <Text style={styles.empty}>Nenhuma notificação ainda</Text> : null}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 16, borderBottomWidth: 1, borderBottomColor: '#eee' },
  rowUnread: { backgroundColor: '#eef2ff' },
  icon: { fontSize: 18 },
  text: { flex: 1, fontSize: 14 },
  empty: { color: '#666', textAlign: 'center', marginTop: 32 },
});
