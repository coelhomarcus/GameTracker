import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { FlatList, Image, Pressable, StyleSheet, Text, View } from 'react-native';
import * as conversationsApi from '../api/conversations';
import * as postsApi from '../api/posts';
import * as usersApi from '../api/users';
import { EmptyState } from '../components/EmptyState';
import { LoadingState } from '../components/LoadingState';
import { PostCard } from '../components/PostCard';
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
      <Pressable style={styles.replyRow} onPress={() => navigation.navigate('PostDetail', { postId: item.post.id })}>
        <Text style={styles.replyContext} numberOfLines={1}>
          Respondeu a <Text style={styles.replyContextUsername}>@{item.post.user.username}</Text>: {item.post.content}
        </Text>
        <Text style={styles.replyContent}>{item.content}</Text>
        <Text style={styles.replyTime}>{formatRelativeTime(item.createdAt)}</Text>
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
      <View style={styles.banner}>
        {profile.bannerUrl && <Image source={{ uri: profile.bannerUrl }} style={styles.bannerImage} />}
      </View>
      <View style={styles.avatarWrap}>
        {profile.avatarUrl ? (
          <Image source={{ uri: profile.avatarUrl }} style={styles.avatarImage} />
        ) : (
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>{profile.username[0]?.toUpperCase()}</Text>
          </View>
        )}
      </View>

      <View style={styles.header}>
        <Text style={styles.username}>{profile.username}</Text>
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

  if (tab === 'replies') {
    return (
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
          activeInfiniteQuery.isLoading ? (
            <LoadingState />
          ) : (
            <EmptyState icon="chatbubble-outline" title="Nenhuma resposta ainda" />
          )
        }
      />
    );
  }

  return (
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
  );
}

const styles = StyleSheet.create({
  list: { paddingBottom: 24, backgroundColor: colors.background },
  banner: { height: 100, backgroundColor: colors.backgroundElevated },
  bannerImage: { width: '100%', height: '100%' },
  avatarWrap: { marginTop: -40, marginLeft: 16 },
  header: { paddingHorizontal: 16, paddingTop: 8, gap: 4, alignItems: 'flex-start' },
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
  bio: { color: colors.textSecondary, marginTop: 4 },
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
  replyRow: { padding: 16, borderBottomWidth: 1, borderBottomColor: colors.border, gap: 4 },
  replyContext: { color: colors.textSecondary, fontSize: 13 },
  replyContextUsername: { color: colors.accent },
  replyContent: { color: colors.textPrimary, fontSize: 15 },
  replyTime: { color: colors.textSecondary, fontSize: 12 },
});
