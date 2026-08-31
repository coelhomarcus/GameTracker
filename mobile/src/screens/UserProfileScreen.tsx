import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { FlatList, Image, Pressable, StyleSheet, Text, View } from 'react-native';
import * as conversationsApi from '../api/conversations';
import * as postsApi from '../api/posts';
import * as usersApi from '../api/users';
import { EmptyState } from '../components/EmptyState';
import { ImageViewerModal } from '../components/ImageViewerModal';
import { LoadingState } from '../components/LoadingState';
import { PostCard } from '../components/PostCard';
import { displayName } from '../lib/displayName';
import { formatRelativeTime } from '../lib/relativeTime';
import { useAuthStore } from '../store/authStore';
import type { RootStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';
import type { Post, UserReply } from '../types/models';

type ProfileTab = 'activities' | 'posts' | 'replies';

const TABS: { value: ProfileTab; label: string }[] = [
  { value: 'activities', label: 'Atividades' },
  { value: 'posts', label: 'Posts' },
  { value: 'replies', label: 'Respostas' },
];

export default function UserProfileScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'UserProfile'>>();
  const { userId } = route.params;
  const myId = useAuthStore((state) => state.user?.id);
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<ProfileTab>('activities');
  const [viewer, setViewer] = useState<'avatar' | 'banner' | null>(null);

  const profileQuery = useQuery({
    queryKey: ['user-profile', userId],
    queryFn: () => usersApi.getPublicProfile(userId),
  });

  const activitiesQuery = useInfiniteQuery({
    queryKey: ['user-posts', userId, 'activity'],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => usersApi.getUserPosts(userId, pageParam, 'activity'),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
    enabled: tab === 'activities',
  });

  const postsTabQuery = useInfiniteQuery({
    queryKey: ['user-posts', userId, 'post'],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => usersApi.getUserPosts(userId, pageParam, 'post'),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
    enabled: tab === 'posts',
  });

  const repliesQuery = useInfiniteQuery({
    queryKey: ['user-replies', userId],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => usersApi.getUserReplies(userId, pageParam),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
    enabled: tab === 'replies',
  });

  const followMutation = useMutation({
    mutationFn: () => (profileQuery.data?.isFollowedByMe ? usersApi.unfollow(userId) : usersApi.follow(userId)),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['user-profile', userId] }),
  });

  const messageMutation = useMutation({
    mutationFn: () => conversationsApi.createOrGetConversation(userId),
    onSuccess: (conversation) => {
      navigation.navigate('ChatRoom', {
        conversationId: conversation.id,
        otherUsername: profileQuery.data!.username,
        otherName: profileQuery.data!.name,
        otherUserId: userId,
        otherAvatarUrl: profileQuery.data!.avatarUrl,
      });
    },
  });

  const likeMutation = useMutation({
    mutationFn: (post: Post) => (post.likedByMe ? postsApi.unlikePost(post.id) : postsApi.likePost(post.id)),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user-posts', userId] });
    },
  });

  if (profileQuery.isLoading || !profileQuery.data) {
    return <LoadingState fullScreen />;
  }

  const profile = profileQuery.data;
  const isMe = myId === userId;

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
          {profile.avatarUrl ? (
            <Image source={{ uri: profile.avatarUrl }} style={styles.threadAvatarImage} />
          ) : (
            <View style={styles.threadAvatar}>
              <Text style={styles.threadAvatarText}>{displayName(profile)[0]?.toUpperCase()}</Text>
            </View>
          )}
          <View style={styles.threadBody}>
            <View style={styles.threadHeaderRow}>
              <Text style={styles.threadName}>{displayName(profile)}</Text>
              <Text style={styles.threadHandle}>@{profile.username}</Text>
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
  const viewerImages = viewer === 'banner' ? (profile.bannerUrl ? [profile.bannerUrl] : []) : profile.avatarUrl ? [profile.avatarUrl] : [];

  const header = (
    <View>
      <Pressable onPress={() => profile.bannerUrl && setViewer('banner')}>
        <View style={styles.banner}>{profile.bannerUrl && <Image source={{ uri: profile.bannerUrl }} style={styles.bannerImage} />}</View>
      </Pressable>

      <View style={styles.avatarRow}>
        <Pressable onPress={() => setViewer('avatar')}>
          {profile.avatarUrl ? (
            <Image source={{ uri: profile.avatarUrl }} style={styles.avatarImage} />
          ) : (
            <View style={styles.avatar}>
              <Text style={styles.avatarText}>{displayName(profile)[0]?.toUpperCase()}</Text>
            </View>
          )}
        </Pressable>

        {!isMe && (
          <View style={styles.actions}>
            <Pressable
              style={[styles.button, profile.isFollowedByMe && styles.buttonFollowing]}
              disabled={followMutation.isPending}
              onPress={() => followMutation.mutate()}
            >
              <Text style={[styles.buttonText, profile.isFollowedByMe && styles.buttonTextFollowing]}>
                {profile.isFollowedByMe ? 'Seguindo' : 'Seguir'}
              </Text>
            </Pressable>
            <Pressable
              style={[styles.button, styles.buttonFollowing]}
              disabled={messageMutation.isPending}
              onPress={() => messageMutation.mutate()}
            >
              <Text style={[styles.buttonText, styles.buttonTextFollowing]}>Mensagem</Text>
            </Pressable>
          </View>
        )}
      </View>

      <View style={styles.header}>
        <Text style={styles.username}>{displayName(profile)}</Text>
        <Text style={styles.handle}>@{profile.username}</Text>
        {profile.bio && <Text style={styles.bio}>{profile.bio}</Text>}

        <View style={styles.stats}>
          <View style={styles.stat}>
            <Text style={styles.statValue}>{profile.gameEntryCount}</Text>
            <Text style={styles.statLabel}>jogos</Text>
          </View>
          <View style={styles.stat}>
            <Text style={styles.statValue}>{profile.followerCount}</Text>
            <Text style={styles.statLabel}>seguidores</Text>
          </View>
          <View style={styles.stat}>
            <Text style={styles.statValue}>{profile.followingCount}</Text>
            <Text style={styles.statLabel}>seguindo</Text>
          </View>
        </View>
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

  return (
    <View style={{ flex: 1 }}>
      {tab === 'replies' ? (
        <FlatList
          data={activeReplies ?? []}
          keyExtractor={(item) => item.id}
          onEndReached={() => {
            if (activeInfiniteQuery.hasNextPage) activeInfiniteQuery.fetchNextPage();
          }}
          onEndReachedThreshold={0.4}
          renderItem={renderReply}
          contentContainerStyle={styles.list}
          ListHeaderComponent={header}
          ListEmptyComponent={
            activeInfiniteQuery.isLoading ? <LoadingState /> : <EmptyState icon="chatbubble-outline" title="Nenhuma resposta ainda" />
          }
        />
      ) : (
        <FlatList
          data={activePosts ?? []}
          keyExtractor={(item) => item.id}
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
          contentContainerStyle={styles.list}
          ListHeaderComponent={header}
          ListEmptyComponent={
            activeInfiniteQuery.isLoading ? (
              <LoadingState />
            ) : tab === 'activities' ? (
              <EmptyState icon="game-controller-outline" title="Nenhuma atividade ainda" />
            ) : (
              <EmptyState icon="document-text-outline" title="Nenhum post ainda" />
            )
          }
        />
      )}

      <ImageViewerModal visible={viewer !== null} images={viewerImages} initialIndex={0} onClose={() => setViewer(null)} />
    </View>
  );
}

const styles = StyleSheet.create({
  list: { paddingBottom: 24, backgroundColor: colors.background },
  banner: { height: 100, backgroundColor: colors.backgroundElevated },
  bannerImage: { width: '100%', height: '100%' },
  avatarRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end', paddingHorizontal: 16, marginTop: -40 },
  header: { paddingHorizontal: 16, paddingTop: 8, gap: 2, alignItems: 'flex-start' },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 3,
    borderColor: colors.background,
  },
  avatarImage: { width: 80, height: 80, borderRadius: 40, borderWidth: 3, borderColor: colors.background },
  avatarText: { color: '#fff', fontSize: 28, fontWeight: '700' },
  username: { fontSize: 20, fontWeight: '700', color: colors.textPrimary, marginTop: 8 },
  handle: { color: colors.textSecondary, fontSize: 14 },
  bio: { color: colors.textPrimary, marginTop: 8 },
  stats: { flexDirection: 'row', gap: 16, marginVertical: 12 },
  stat: { flexDirection: 'row', gap: 4, alignItems: 'baseline' },
  statValue: { fontSize: 15, fontWeight: '700', color: colors.textPrimary },
  statLabel: { color: colors.textSecondary, fontSize: 13 },
  actions: { flexDirection: 'row', gap: 12 },
  button: { backgroundColor: colors.accent, borderRadius: 8, paddingVertical: 10, paddingHorizontal: 24 },
  buttonFollowing: { backgroundColor: 'transparent', borderWidth: 1, borderColor: colors.border },
  buttonText: { color: '#fff', fontWeight: '600' },
  buttonTextFollowing: { color: colors.textPrimary },
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
