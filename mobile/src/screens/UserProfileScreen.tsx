import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { FlatList, Image, Pressable, StyleSheet, Text, useWindowDimensions, View } from 'react-native';
import * as conversationsApi from '../api/conversations';
import * as postsApi from '../api/posts';
import * as usersApi from '../api/users';
import { EmptyState } from '../components/EmptyState';
import { GameEntryGridCell } from '../components/GameEntryGridCell';
import { ImageViewerModal } from '../components/ImageViewerModal';
import { LoadingState } from '../components/LoadingState';
import { PostCard } from '../components/PostCard';
import { ReplyThreadCard } from '../components/ReplyThreadCard';
import { StatusFilterChips } from '../components/StatusFilterChips';
import { displayName } from '../lib/displayName';
import { useAuthStore } from '../store/authStore';
import type { RootStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';
import { radius } from '../theme/radius';
import type { GameEntryStatus, Post, UserReply } from '../types/models';

type ProfileTab = 'backlog' | 'activities' | 'posts' | 'replies';

const TABS: { value: ProfileTab; label: string }[] = [
  { value: 'backlog', label: 'Backlog' },
  { value: 'activities', label: 'Atividades' },
  { value: 'posts', label: 'Posts' },
  { value: 'replies', label: 'Respostas' },
];

const GRID_COLUMNS = 4;
const GRID_GAP = 8;
const CONTAINER_PADDING = 16;

export default function UserProfileScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'UserProfile'>>();
  const { userId } = route.params;
  const myId = useAuthStore((state) => state.user?.id);
  const isMe = !!myId && userId === myId;
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<ProfileTab>('backlog');
  const [viewer, setViewer] = useState<'avatar' | 'banner' | null>(null);
  const [gameFilter, setGameFilter] = useState<GameEntryStatus | 'all'>('all');
  const { width } = useWindowDimensions();
  const cellWidth = (width - CONTAINER_PADDING * 2 - GRID_GAP * (GRID_COLUMNS - 1)) / GRID_COLUMNS;

  // "Meu perfil" tem uma tela própria (com edição, configurações etc.) — se chegou
  // aqui vendo a si mesmo (ex: tocando no próprio nome num post do feed), redireciona
  // pra lá em vez de mostrar uma versão incompleta "de visitante" do próprio perfil.
  useEffect(() => {
    if (isMe) navigation.replace('Profile');
  }, [isMe, navigation]);

  const profileQuery = useQuery({
    queryKey: ['user-profile', userId],
    queryFn: () => usersApi.getPublicProfile(userId),
    enabled: !isMe,
  });

  const backlogQuery = useQuery({
    queryKey: ['user-game-entries', userId, gameFilter],
    queryFn: () => usersApi.getUserGameEntries(userId, gameFilter === 'all' ? undefined : gameFilter),
    enabled: !isMe && tab === 'backlog',
  });

  const activitiesQuery = useInfiniteQuery({
    queryKey: ['user-posts', userId, 'activity'],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => usersApi.getUserPosts(userId, pageParam, 'activity'),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
    enabled: !isMe && tab === 'activities',
  });

  const postsTabQuery = useInfiniteQuery({
    queryKey: ['user-posts', userId, 'post'],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => usersApi.getUserPosts(userId, pageParam, 'post'),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
    enabled: !isMe && tab === 'posts',
  });

  const repliesQuery = useInfiniteQuery({
    queryKey: ['user-replies', userId],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => usersApi.getUserReplies(userId, pageParam),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
    enabled: !isMe && tab === 'replies',
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

  if (isMe || profileQuery.isLoading || !profileQuery.data) {
    return <LoadingState fullScreen />;
  }

  const profile = profileQuery.data;

  function renderReply({ item }: { item: UserReply }) {
    return (
      <ReplyThreadCard
        reply={item}
        author={profile}
        onPress={() => navigation.navigate('PostDetail', { postId: item.post.id })}
      />
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

      {tab === 'backlog' && <StatusFilterChips value={gameFilter} onChange={setGameFilter} />}
    </View>
  );

  return (
    <View style={{ flex: 1 }}>
      {tab === 'backlog' ? (
        <FlatList
          key={`backlog-${GRID_COLUMNS}`}
          data={backlogQuery.data ?? []}
          keyExtractor={(item) => item.id}
          numColumns={GRID_COLUMNS}
          columnWrapperStyle={styles.gridRow}
          contentContainerStyle={styles.list}
          renderItem={({ item }) => (
            <GameEntryGridCell entry={item} width={cellWidth} onPress={() => navigation.navigate('GameFocus', { igdbId: item.game.igdbId })} />
          )}
          ListHeaderComponent={header}
          ListEmptyComponent={
            backlogQuery.isLoading ? (
              <LoadingState />
            ) : (
              <EmptyState
                icon="game-controller-outline"
                title={gameFilter === 'all' ? 'Nenhum jogo por aqui ainda' : 'Nenhum jogo nesse status'}
              />
            )
          }
        />
      ) : tab === 'replies' ? (
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
  button: { backgroundColor: colors.accent, borderRadius: radius.pill, paddingVertical: 10, paddingHorizontal: 24 },
  buttonFollowing: { backgroundColor: 'transparent', borderWidth: 1, borderColor: colors.border },
  buttonText: { color: '#fff', fontWeight: '600' },
  buttonTextFollowing: { color: colors.textPrimary },
  tabs: { flexDirection: 'row', borderBottomWidth: 1, borderBottomColor: colors.border, marginTop: 16 },
  tab: { flex: 1, alignItems: 'center', paddingVertical: 12 },
  tabText: { color: colors.textSecondary, fontWeight: '600', fontSize: 13 },
  tabTextActive: { color: colors.textPrimary },
  tabIndicator: { position: 'absolute', bottom: 0, height: 2, width: '50%', backgroundColor: colors.accent, borderRadius: 1 },
  gridRow: { gap: GRID_GAP, marginBottom: GRID_GAP, paddingHorizontal: 16 },
});
