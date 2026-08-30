import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useInfiniteQuery, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { FlatList, Pressable, RefreshControl, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as notificationsApi from '../api/notifications';
import * as postsApi from '../api/posts';
import { PostCard } from '../components/PostCard';
import type { RootStackParamList } from '../navigation/types';
import type { FeedScope, Post } from '../types/models';

const SCOPES: { value: FeedScope; label: string }[] = [
  { value: 'general', label: 'Para você' },
  { value: 'following', label: 'Seguindo' },
];

export default function FeedScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const queryClient = useQueryClient();
  const insets = useSafeAreaInsets();
  const [scope, setScope] = useState<FeedScope>('general');

  const feedQuery = useInfiniteQuery({
    queryKey: ['feed', scope],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => postsApi.getFeed(scope, pageParam),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
  });

  const notificationsQuery = useQuery({
    queryKey: ['notifications'],
    queryFn: notificationsApi.listNotifications,
    refetchInterval: 30_000,
  });

  const posts = feedQuery.data?.pages.flatMap((page) => page.items) ?? [];

  async function toggleLike(post: Post) {
    if (post.likedByMe) {
      await postsApi.unlikePost(post.id);
    } else {
      await postsApi.likePost(post.id);
    }
    queryClient.invalidateQueries({ queryKey: ['feed'] });
  }

  return (
    <View style={styles.container}>
      <View style={[styles.header, { paddingTop: insets.top + 16 }]}>
        <Text style={styles.title}>GameTracker</Text>
        <View style={styles.headerActions}>
          <Pressable onPress={() => navigation.navigate('Notifications')} style={styles.iconButton}>
            <Ionicons name="notifications-outline" size={22} color="#111" />
            {!!notificationsQuery.data?.unreadCount && (
              <View style={styles.badge}>
                <Text style={styles.badgeText}>{notificationsQuery.data.unreadCount}</Text>
              </View>
            )}
          </Pressable>
          <Pressable onPress={() => navigation.navigate('CreatePost', undefined)} style={styles.iconButton}>
            <Ionicons name="add-circle-outline" size={22} color="#111" />
          </Pressable>
        </View>
      </View>

      <View style={styles.scopeTabs}>
        {SCOPES.map((s) => (
          <Pressable key={s.value} style={styles.scopeTab} onPress={() => setScope(s.value)}>
            <Text style={[styles.scopeTabText, scope === s.value && styles.scopeTabTextActive]}>{s.label}</Text>
            {scope === s.value && <View style={styles.scopeTabIndicator} />}
          </Pressable>
        ))}
      </View>

      <FlatList
        data={posts}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.list}
        renderItem={({ item }) => (
          <PostCard
            post={item}
            onPress={() => navigation.navigate('PostDetail', { postId: item.id })}
            onAuthorPress={() => navigation.navigate('UserProfile', { userId: item.userId })}
            onToggleLike={() => toggleLike(item)}
          />
        )}
        refreshControl={<RefreshControl refreshing={feedQuery.isRefetching} onRefresh={() => feedQuery.refetch()} />}
        onEndReached={() => {
          if (feedQuery.hasNextPage) feedQuery.fetchNextPage();
        }}
        onEndReachedThreshold={0.4}
        ListEmptyComponent={
          !feedQuery.isLoading ? (
            <Text style={styles.empty}>
              {scope === 'following'
                ? 'Nenhum post de quem você segue ainda. Que tal achar gente nova?'
                : 'Nenhum post ainda. Crie o primeiro!'}
            </Text>
          ) : null
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    paddingBottom: 12,
  },
  title: { fontSize: 20, fontWeight: '700' },
  headerActions: { flexDirection: 'row', gap: 8 },
  iconButton: { padding: 6 },
  badge: {
    position: 'absolute',
    top: 0,
    right: 0,
    backgroundColor: '#dc2626',
    borderRadius: 8,
    minWidth: 16,
    height: 16,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 3,
  },
  badgeText: { color: '#fff', fontSize: 10, fontWeight: '700' },
  scopeTabs: { flexDirection: 'row', borderBottomWidth: 1, borderBottomColor: '#eee' },
  scopeTab: { flex: 1, alignItems: 'center', paddingVertical: 12 },
  scopeTabText: { color: '#666', fontWeight: '600', fontSize: 14 },
  scopeTabTextActive: { color: '#111' },
  scopeTabIndicator: { position: 'absolute', bottom: 0, height: 2, width: '40%', backgroundColor: '#4f46e5', borderRadius: 1 },
  list: { padding: 16, gap: 12 },
  empty: { color: '#666', textAlign: 'center', marginTop: 32 },
});
