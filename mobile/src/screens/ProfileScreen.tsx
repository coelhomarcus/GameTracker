import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { FlatList, Image, Pressable, StyleSheet, Text, View } from 'react-native';
import * as postsApi from '../api/posts';
import * as usersApi from '../api/users';
import { EmptyState } from '../components/EmptyState';
import { ImageViewerModal } from '../components/ImageViewerModal';
import { KeyboardAvoidingScreen } from '../components/KeyboardAvoidingScreen';
import { LoadingState } from '../components/LoadingState';
import { PostCard } from '../components/PostCard';
import { displayName } from '../lib/displayName';
import { formatRelativeTime } from '../lib/relativeTime';
import type { RootStackParamList } from '../navigation/types';
import { useAuthStore } from '../store/authStore';
import { colors } from '../theme/colors';
import type { Post, UserReply } from '../types/models';

type ProfileTab = 'activities' | 'posts' | 'replies';

const TABS: { value: ProfileTab; label: string }[] = [
  { value: 'activities', label: 'Atividades' },
  { value: 'posts', label: 'Posts' },
  { value: 'replies', label: 'Respostas' },
];

export default function ProfileScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const user = useAuthStore((state) => state.user);
  const queryClient = useQueryClient();

  const [tab, setTab] = useState<ProfileTab>('activities');
  const [viewer, setViewer] = useState<'avatar' | 'banner' | null>(null);

  const profileQuery = useQuery({
    queryKey: ['user-profile', user?.id],
    queryFn: () => usersApi.getPublicProfile(user!.id),
    enabled: !!user,
  });

  const activitiesQuery = useInfiniteQuery({
    queryKey: ['user-posts', user?.id, 'activity'],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => usersApi.getUserPosts(user!.id, pageParam, 'activity'),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
    enabled: !!user && tab === 'activities',
  });

  const postsTabQuery = useInfiniteQuery({
    queryKey: ['user-posts', user?.id, 'post'],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => usersApi.getUserPosts(user!.id, pageParam, 'post'),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
    enabled: !!user && tab === 'posts',
  });

  const repliesQuery = useInfiniteQuery({
    queryKey: ['user-replies', user?.id],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => usersApi.getUserReplies(user!.id, pageParam),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
    enabled: !!user && tab === 'replies',
  });

  const likeMutation = useMutation({
    mutationFn: (post: Post) => (post.likedByMe ? postsApi.unlikePost(post.id) : postsApi.likePost(post.id)),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user-posts', user?.id] });
    },
  });

  function renderReply({ item }: { item: UserReply }) {
    return (
      <Pressable style={styles.replyContainer} onPress={() => navigation.navigate('PostDetail', { postId: item.post.id })}>
        <View style={styles.threadRow}>
          <View style={styles.threadAvatarCol}>
            {item.post.user.avatarUrl ? (
              <Image source={{ uri: item.post.user.avatarUrl }} style={styles.threadAvatarImage} />
            ) : (
              <View style={styles.threadAvatar}>
                <Text style={styles.threadAvatarText}>{displayName(item.post.user)[0]?.toUpperCase()}</Text>
              </View>
            )}
            <View style={styles.threadLine} />
          </View>
          <View style={styles.threadBody}>
            <View style={styles.threadHeaderRow}>
              <Text style={styles.threadName}>{displayName(item.post.user)}</Text>
              <Text style={styles.threadHandle}>@{item.post.user.username}</Text>
            </View>
            <Text style={styles.threadContent} numberOfLines={3}>
              {item.post.content}
            </Text>
          </View>
        </View>

        <View style={styles.threadRow}>
          {user?.avatarUrl ? (
            <Image source={{ uri: user.avatarUrl }} style={styles.threadAvatarImage} />
          ) : (
            <View style={styles.threadAvatar}>
              <Text style={styles.threadAvatarText}>{user ? displayName(user)[0]?.toUpperCase() : '?'}</Text>
            </View>
          )}
          <View style={styles.threadBody}>
            <View style={styles.threadHeaderRow}>
              <Text style={styles.threadName}>{user ? displayName(user) : ''}</Text>
              <Text style={styles.threadHandle}>@{user?.username}</Text>
              <Text style={styles.threadHandle}>· {formatRelativeTime(item.createdAt)}</Text>
            </View>
            <Text style={styles.threadContent}>{item.content}</Text>
          </View>
        </View>
      </Pressable>
    );
  }

  const activePosts =
    tab === 'activities'
      ? activitiesQuery.data?.pages.flatMap((page) => page.items)
      : tab === 'posts'
        ? postsTabQuery.data?.pages.flatMap((page) => page.items)
        : undefined;
  const activeReplies = tab === 'replies' ? repliesQuery.data?.pages.flatMap((page) => page.items) : undefined;
  const activeInfiniteQuery = tab === 'activities' ? activitiesQuery : tab === 'posts' ? postsTabQuery : repliesQuery;

  const header = (
    <View>
      <Pressable onPress={() => user?.bannerUrl && setViewer('banner')}>
        {user?.bannerUrl ? <Image source={{ uri: user.bannerUrl }} style={styles.banner} /> : <View style={styles.banner} />}
      </Pressable>

      <View style={styles.avatarRow}>
        <Pressable onPress={() => setViewer('avatar')} style={styles.avatar}>
          {user?.avatarUrl ? (
            <Image source={{ uri: user.avatarUrl }} style={styles.avatarImage} />
          ) : (
            <Text style={styles.avatarText}>{user ? displayName(user)[0]?.toUpperCase() : '?'}</Text>
          )}
        </Pressable>
        <Pressable style={styles.editButton} onPress={() => navigation.navigate('EditProfile')}>
          <Text style={styles.editButtonText}>Editar perfil</Text>
        </Pressable>
      </View>

      <View style={styles.header}>
        <Text style={styles.username}>{user ? displayName(user) : ''}</Text>
        <Text style={styles.handle}>@{user?.username}</Text>

        {user?.bio ? <Text style={styles.bio}>{user.bio}</Text> : null}

        {profileQuery.data && (
          <View style={styles.stats}>
            <View style={styles.stat}>
              <Text style={styles.statValue}>{profileQuery.data.gameEntryCount}</Text>
              <Text style={styles.statLabel}>jogos</Text>
            </View>
            <View style={styles.stat}>
              <Text style={styles.statValue}>{profileQuery.data.followerCount}</Text>
              <Text style={styles.statLabel}>seguidores</Text>
            </View>
            <View style={styles.stat}>
              <Text style={styles.statValue}>{profileQuery.data.followingCount}</Text>
              <Text style={styles.statLabel}>seguindo</Text>
            </View>
          </View>
        )}
      </View>

      <View style={styles.tabs}>
        {TABS.map((t) => (
          <Pressable key={t.value} style={styles.tab} onPress={() => setTab(t.value)}>
            <Text style={[styles.tabText, tab === t.value && styles.tabTextActive]}>{t.label}</Text>
            {tab === t.value && <View style={styles.tabIndicator} />}
          </Pressable>
        ))}
      </View>
    </View>
  );

  const viewerImages = viewer === 'banner' ? (user?.bannerUrl ? [user.bannerUrl] : []) : user?.avatarUrl ? [user.avatarUrl] : [];

  return (
    <KeyboardAvoidingScreen>
      {tab === 'replies' ? (
        <FlatList
          data={activeReplies ?? []}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          onEndReached={() => {
            if (activeInfiniteQuery.hasNextPage) activeInfiniteQuery.fetchNextPage();
          }}
          onEndReachedThreshold={0.4}
          renderItem={renderReply}
          ListHeaderComponent={header}
          ListEmptyComponent={
            activeInfiniteQuery.isLoading ? <LoadingState /> : <EmptyState icon="chatbubble-outline" title="Nenhuma resposta ainda" />
          }
        />
      ) : (
        <FlatList
          data={activePosts ?? []}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          onEndReached={() => {
            if (activeInfiniteQuery.hasNextPage) activeInfiniteQuery.fetchNextPage();
          }}
          onEndReachedThreshold={0.4}
          renderItem={({ item }) => (
            <PostCard
              post={item}
              onPress={() => navigation.navigate('PostDetail', { postId: item.id })}
              onAuthorPress={() => {}}
              onToggleLike={() => likeMutation.mutate(item)}
            />
          )}
          ListHeaderComponent={header}
          ListEmptyComponent={
            activeInfiniteQuery.isLoading ? (
              <LoadingState />
            ) : tab === 'activities' ? (
              <EmptyState icon="game-controller-outline" title="Nenhuma atividade ainda" subtitle="Trackeie um jogo pra ver suas atividades aqui" />
            ) : (
              <EmptyState icon="document-text-outline" title="Nenhum post ainda" subtitle="Compartilhe algo na sua timeline" />
            )
          }
        />
      )}

      <ImageViewerModal visible={viewer !== null} images={viewerImages} initialIndex={0} onClose={() => setViewer(null)} />
    </KeyboardAvoidingScreen>
  );
}

const styles = StyleSheet.create({
  list: { paddingBottom: 24, backgroundColor: colors.background },
  banner: { height: 100, backgroundColor: colors.backgroundElevated },
  avatarRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end', paddingHorizontal: 16, marginTop: -40 },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 3,
    borderColor: colors.background,
    overflow: 'visible',
  },
  avatarImage: { width: 80, height: 80, borderRadius: 40 },
  avatarText: { color: '#fff', fontSize: 30, fontWeight: '700' },
  editButton: { borderWidth: 1, borderColor: colors.border, borderRadius: 16, paddingVertical: 8, paddingHorizontal: 16 },
  editButtonText: { color: colors.textPrimary, fontWeight: '600', fontSize: 13 },
  header: { paddingHorizontal: 16, paddingTop: 8, gap: 2, alignItems: 'flex-start' },
  username: { fontSize: 20, fontWeight: '700', color: colors.textPrimary, marginTop: 8 },
  handle: { color: colors.textSecondary, fontSize: 14 },
  bio: { color: colors.textPrimary, marginTop: 8 },
  stats: { flexDirection: 'row', gap: 16, marginVertical: 12 },
  stat: { flexDirection: 'row', gap: 4, alignItems: 'baseline' },
  statValue: { fontSize: 15, fontWeight: '700', color: colors.textPrimary },
  statLabel: { color: colors.textSecondary, fontSize: 13 },
  tabs: { flexDirection: 'row', borderBottomWidth: 1, borderBottomColor: colors.border, marginTop: 16 },
  tab: { flex: 1, alignItems: 'center', paddingVertical: 12 },
  tabText: { color: colors.textSecondary, fontWeight: '600', fontSize: 13 },
  tabTextActive: { color: colors.textPrimary },
  tabIndicator: { position: 'absolute', bottom: 0, height: 2, width: '50%', backgroundColor: colors.accent, borderRadius: 1 },
  replyContainer: { padding: 16, borderBottomWidth: 1, borderBottomColor: colors.border, gap: 8 },
  threadRow: { flexDirection: 'row', gap: 10 },
  threadAvatarCol: { alignItems: 'center' },
  threadAvatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },
  threadAvatarImage: { width: 32, height: 32, borderRadius: 16 },
  threadAvatarText: { color: '#fff', fontWeight: '700', fontSize: 13 },
  threadLine: { width: 2, flex: 1, backgroundColor: colors.border, marginTop: 4, marginBottom: -4 },
  threadBody: { flex: 1, gap: 2, paddingBottom: 4 },
  threadHeaderRow: { flexDirection: 'row', alignItems: 'baseline', gap: 4, flexWrap: 'wrap' },
  threadName: { fontWeight: '600', color: colors.textPrimary, fontSize: 13 },
  threadHandle: { color: colors.textSecondary, fontSize: 12 },
  threadContent: { color: colors.textPrimary, fontSize: 14 },
});
