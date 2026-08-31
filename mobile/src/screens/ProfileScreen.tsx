import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import * as ImagePicker from 'expo-image-picker';
import { useState } from 'react';
import { ActivityIndicator, FlatList, Image, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import * as postsApi from '../api/posts';
import * as usersApi from '../api/users';
import { EmptyState } from '../components/EmptyState';
import { KeyboardAvoidingScreen } from '../components/KeyboardAvoidingScreen';
import { LoadingState } from '../components/LoadingState';
import { PostCard } from '../components/PostCard';
import { getApiErrorMessage } from '../lib/apiError';
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
  const updateUser = useAuthStore((state) => state.updateUser);
  const queryClient = useQueryClient();

  const [tab, setTab] = useState<ProfileTab>('activities');
  const [editingBio, setEditingBio] = useState(false);
  const [bioDraft, setBioDraft] = useState(user?.bio ?? '');
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [uploadingBanner, setUploadingBanner] = useState(false);

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

  const bioMutation = useMutation({
    mutationFn: (bio: string) => usersApi.updateProfile({ bio }),
    onSuccess: (_data, bio) => {
      updateUser({ bio });
      queryClient.invalidateQueries({ queryKey: ['user-profile', user?.id] });
      setEditingBio(false);
    },
  });

  const likeMutation = useMutation({
    mutationFn: (post: Post) => (post.likedByMe ? postsApi.unlikePost(post.id) : postsApi.likePost(post.id)),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user-posts', user?.id] });
    },
  });

  async function handlePickAvatar() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) return;

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.8,
    });
    if (result.canceled || !result.assets[0]) return;

    setUploadingAvatar(true);
    try {
      const { avatarUrl } = await usersApi.uploadAvatar(result.assets[0].uri);
      updateUser({ avatarUrl });
    } finally {
      setUploadingAvatar(false);
    }
  }

  async function handlePickBanner() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) return;

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [3, 1],
      quality: 0.8,
    });
    if (result.canceled || !result.assets[0]) return;

    setUploadingBanner(true);
    try {
      const { bannerUrl } = await usersApi.uploadBanner(result.assets[0].uri);
      updateUser({ bannerUrl });
    } finally {
      setUploadingBanner(false);
    }
  }

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
      <Pressable onPress={handlePickBanner}>
        {user?.bannerUrl ? (
          <Image source={{ uri: user.bannerUrl }} style={styles.banner} />
        ) : (
          <View style={styles.banner} />
        )}
        <View style={styles.bannerEditBadge}>
          {uploadingBanner ? <ActivityIndicator size="small" color="#fff" /> : <Ionicons name="camera" size={14} color="#fff" />}
        </View>
      </Pressable>

      <View style={styles.avatarWrap}>
        <Pressable onPress={handlePickAvatar} style={styles.avatar}>
          {user?.avatarUrl ? (
            <Image source={{ uri: user.avatarUrl }} style={styles.avatarImage} />
          ) : (
            <Text style={styles.avatarText}>{user?.username?.[0]?.toUpperCase() ?? '?'}</Text>
          )}
          <View style={styles.avatarEditBadge}>
            {uploadingAvatar ? (
              <ActivityIndicator size="small" color="#fff" />
            ) : (
              <Ionicons name="camera" size={14} color="#fff" />
            )}
          </View>
        </Pressable>
      </View>

      <View style={styles.header}>
        <Text style={styles.username}>{user?.username}</Text>
        <Text style={styles.email}>{user?.email}</Text>

        {editingBio ? (
          <View style={styles.bioEdit}>
            <TextInput
              style={styles.bioInput}
              value={bioDraft}
              onChangeText={setBioDraft}
              placeholder="Fale um pouco sobre você..."
              placeholderTextColor={colors.textSecondary}
              multiline
              maxLength={280}
            />
            {bioMutation.isError && <Text style={styles.error}>{getApiErrorMessage(bioMutation.error)}</Text>}
            <View style={styles.bioEditActions}>
              <Pressable onPress={() => setEditingBio(false)}>
                <Text style={styles.bioCancel}>Cancelar</Text>
              </Pressable>
              <Pressable onPress={() => bioMutation.mutate(bioDraft)} disabled={bioMutation.isPending}>
                <Text style={styles.bioSave}>{bioMutation.isPending ? 'Salvando...' : 'Salvar'}</Text>
              </Pressable>
            </View>
          </View>
        ) : (
          <Pressable onPress={() => setEditingBio(true)}>
            <Text style={user?.bio ? styles.bio : styles.bioPlaceholder}>{user?.bio ?? 'Adicionar bio'}</Text>
          </Pressable>
        )}

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

  if (tab === 'replies') {
    return (
      <KeyboardAvoidingScreen>
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
            activeInfiniteQuery.isLoading ? (
              <LoadingState />
            ) : (
              <EmptyState icon="chatbubble-outline" title="Nenhuma resposta ainda" />
            )
          }
        />
      </KeyboardAvoidingScreen>
    );
  }

  return (
    <KeyboardAvoidingScreen>
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
    </KeyboardAvoidingScreen>
  );
}

const styles = StyleSheet.create({
  list: { paddingBottom: 24, backgroundColor: colors.background },
  banner: { height: 100, backgroundColor: colors.backgroundElevated },
  bannerEditBadge: {
    position: 'absolute',
    bottom: 8,
    right: 8,
    backgroundColor: colors.accent,
    borderRadius: 12,
    width: 26,
    height: 26,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: colors.background,
  },
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
    overflow: 'visible',
  },
  avatarImage: { width: 80, height: 80, borderRadius: 40 },
  avatarText: { color: '#fff', fontSize: 30, fontWeight: '700' },
  avatarEditBadge: {
    position: 'absolute',
    bottom: -2,
    right: -2,
    backgroundColor: colors.accent,
    borderRadius: 12,
    width: 24,
    height: 24,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: colors.background,
  },
  username: { fontSize: 20, fontWeight: '700', color: colors.textPrimary, marginTop: 8 },
  email: { color: colors.textSecondary, fontSize: 13 },
  bio: { color: colors.textPrimary, marginTop: 8 },
  bioPlaceholder: { color: colors.textSecondary, marginTop: 8, fontStyle: 'italic' },
  bioEdit: { width: '100%', marginTop: 8, gap: 6 },
  bioInput: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 8,
    padding: 10,
    minHeight: 60,
    textAlignVertical: 'top',
    color: colors.textPrimary,
  },
  bioEditActions: { flexDirection: 'row', justifyContent: 'flex-end', gap: 16 },
  bioCancel: { color: colors.textSecondary },
  bioSave: { color: colors.accent, fontWeight: '600' },
  error: { color: colors.like, fontSize: 12 },
  stats: { flexDirection: 'row', gap: 16, marginVertical: 12 },
  stat: { flexDirection: 'row', gap: 4, alignItems: 'baseline' },
  statValue: { fontSize: 15, fontWeight: '700', color: colors.textPrimary },
  statLabel: { color: colors.textSecondary, fontSize: 13 },
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
