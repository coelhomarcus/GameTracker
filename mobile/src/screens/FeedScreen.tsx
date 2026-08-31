import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useInfiniteQuery, useQueryClient } from '@tanstack/react-query';
import { BlurView } from 'expo-blur';
import { useState } from 'react';
import { FlatList, Image, Pressable, RefreshControl, StyleSheet, Text, View, type LayoutChangeEvent } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as postsApi from '../api/posts';
import { EmptyState } from '../components/EmptyState';
import { LoadingState } from '../components/LoadingState';
import { PostCard } from '../components/PostCard';
import { displayName } from '../lib/displayName';
import type { RootStackParamList } from '../navigation/types';
import { useAuthStore } from '../store/authStore';
import { colors } from '../theme/colors';
import type { FeedScope, Post } from '../types/models';

const SCOPES: { value: FeedScope; label: string }[] = [
  { value: 'general', label: 'Para você' },
  { value: 'following', label: 'Seguindo' },
];

export default function FeedScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const queryClient = useQueryClient();
  const insets = useSafeAreaInsets();
  const user = useAuthStore((state) => state.user);
  const [scope, setScope] = useState<FeedScope>('general');
  const [headerHeight, setHeaderHeight] = useState(insets.top + 116);

  function onHeaderLayout(event: LayoutChangeEvent) {
    setHeaderHeight(event.nativeEvent.layout.height);
  }

  const feedQuery = useInfiniteQuery({
    queryKey: ['feed', scope],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => postsApi.getFeed(scope, pageParam),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
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
      <FlatList
        data={posts}
        keyExtractor={(item) => item.id}
        contentContainerStyle={[styles.list, { paddingTop: headerHeight }]}
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
          feedQuery.isLoading ? (
            <LoadingState />
          ) : scope === 'following' ? (
            <EmptyState
              icon="people-outline"
              title="Nenhum post de quem você segue ainda"
              subtitle="Que tal achar gente nova pra seguir?"
            />
          ) : (
            <EmptyState icon="newspaper-outline" title="Nenhum post ainda" subtitle="Crie o primeiro post pra começar" />
          )
        }
      />

      <Pressable style={styles.fab} onPress={() => navigation.navigate('CreatePost', undefined)}>
        <Ionicons name="add" size={28} color="#fff" />
      </Pressable>

      <BlurView intensity={70} tint="dark" style={styles.headerWrap} onLayout={onHeaderLayout}>
        <View style={[styles.header, { paddingTop: insets.top + 16 }]}>
          <Pressable onPress={() => navigation.navigate('Profile')} hitSlop={8}>
            {user?.avatarUrl ? (
              <Image source={{ uri: user.avatarUrl }} style={styles.avatarImage} />
            ) : (
              <View style={styles.avatar}>
                <Text style={styles.avatarText}>{user ? displayName(user)[0]?.toUpperCase() : '?'}</Text>
              </View>
            )}
          </Pressable>
          <Text style={styles.title}>GameTracker</Text>
          <View style={styles.headerSpacer} />
        </View>

        <View style={styles.scopeTabs}>
          {SCOPES.map((s) => (
            <Pressable key={s.value} style={styles.scopeTab} onPress={() => setScope(s.value)}>
              <Text style={[styles.scopeTabText, scope === s.value && styles.scopeTabTextActive]}>{s.label}</Text>
              {scope === s.value && <View style={styles.scopeTabIndicator} />}
            </Pressable>
          ))}
        </View>
      </BlurView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    paddingBottom: 12,
  },
  title: { fontSize: 18, fontWeight: '700', color: colors.textPrimary },
  headerSpacer: { width: 30 },
  avatar: {
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: { color: '#fff', fontWeight: '700', fontSize: 12 },
  avatarImage: { width: 30, height: 30, borderRadius: 15 },
  scopeTabs: { flexDirection: 'row', borderBottomWidth: 1, borderBottomColor: colors.border },
  scopeTab: { flex: 1, alignItems: 'center', paddingVertical: 12 },
  scopeTabText: { color: colors.textSecondary, fontWeight: '600', fontSize: 14 },
  scopeTabTextActive: { color: colors.textPrimary },
  scopeTabIndicator: { position: 'absolute', bottom: 0, height: 2, width: '40%', backgroundColor: colors.accent, borderRadius: 1 },
  list: { paddingBottom: 96 },
  headerWrap: { position: 'absolute', top: 0, left: 0, right: 0, overflow: 'hidden' },
  fab: {
    position: 'absolute',
    right: 20,
    bottom: 24,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 4,
    shadowColor: '#000',
    shadowOpacity: 0.3,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 2 },
  },
});
