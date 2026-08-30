import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import * as ImagePicker from 'expo-image-picker';
import { useState } from 'react';
import { ActivityIndicator, FlatList, Image, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import * as authApi from '../api/auth';
import * as postsApi from '../api/posts';
import * as usersApi from '../api/users';
import { PostCard } from '../components/PostCard';
import { getApiErrorMessage } from '../lib/apiError';
import { clearSessionEverywhere } from '../lib/session';
import type { RootStackParamList } from '../navigation/types';
import { useAuthStore } from '../store/authStore';
import type { Post } from '../types/models';

export default function ProfileScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const user = useAuthStore((state) => state.user);
  const refreshToken = useAuthStore((state) => state.refreshToken);
  const updateUser = useAuthStore((state) => state.updateUser);
  const queryClient = useQueryClient();

  const [editingBio, setEditingBio] = useState(false);
  const [bioDraft, setBioDraft] = useState(user?.bio ?? '');
  const [uploadingAvatar, setUploadingAvatar] = useState(false);

  const profileQuery = useQuery({
    queryKey: ['user-profile', user?.id],
    queryFn: () => usersApi.getPublicProfile(user!.id),
    enabled: !!user,
  });

  const postsQuery = useInfiniteQuery({
    queryKey: ['user-posts', user?.id],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => usersApi.getUserPosts(user!.id, pageParam),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
    enabled: !!user,
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
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['user-posts', user?.id] }),
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

  async function handleLogout() {
    try {
      if (refreshToken) await authApi.logout(refreshToken);
    } finally {
      await clearSessionEverywhere();
    }
  }

  const posts = postsQuery.data?.pages.flatMap((page) => page.items) ?? [];

  return (
    <FlatList
      data={posts}
      keyExtractor={(item) => item.id}
      contentContainerStyle={styles.list}
      onEndReached={() => {
        if (postsQuery.hasNextPage) postsQuery.fetchNextPage();
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
      ListHeaderComponent={
        <View style={styles.header}>
          <Pressable onPress={handleLogout} style={styles.logoutButton}>
            <Ionicons name="log-out-outline" size={20} color="#dc2626" />
          </Pressable>

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

          <Text style={styles.username}>{user?.username}</Text>
          <Text style={styles.email}>{user?.email}</Text>

          {editingBio ? (
            <View style={styles.bioEdit}>
              <TextInput
                style={styles.bioInput}
                value={bioDraft}
                onChangeText={setBioDraft}
                placeholder="Fale um pouco sobre você..."
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

          <Text style={styles.sectionTitle}>Atividades</Text>
        </View>
      }
      ListEmptyComponent={!postsQuery.isLoading ? <Text style={styles.empty}>Nenhuma atividade ainda</Text> : null}
    />
  );
}

const styles = StyleSheet.create({
  list: { paddingBottom: 24 },
  header: { alignItems: 'center', padding: 24, gap: 4 },
  logoutButton: { position: 'absolute', top: 16, right: 16, padding: 6 },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#4f46e5',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
    overflow: 'visible',
  },
  avatarImage: { width: 80, height: 80, borderRadius: 40 },
  avatarText: { color: '#fff', fontSize: 30, fontWeight: '700' },
  avatarEditBadge: {
    position: 'absolute',
    bottom: -2,
    right: -2,
    backgroundColor: '#4f46e5',
    borderRadius: 12,
    width: 24,
    height: 24,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: '#fff',
  },
  username: { fontSize: 20, fontWeight: '700' },
  email: { color: '#666', fontSize: 13 },
  bio: { color: '#333', textAlign: 'center', marginTop: 8, paddingHorizontal: 16 },
  bioPlaceholder: { color: '#999', textAlign: 'center', marginTop: 8, fontStyle: 'italic' },
  bioEdit: { width: '100%', marginTop: 8, gap: 6 },
  bioInput: { borderWidth: 1, borderColor: '#ccc', borderRadius: 8, padding: 10, minHeight: 60, textAlignVertical: 'top' },
  bioEditActions: { flexDirection: 'row', justifyContent: 'flex-end', gap: 16 },
  bioCancel: { color: '#666' },
  bioSave: { color: '#4f46e5', fontWeight: '600' },
  error: { color: '#dc2626', fontSize: 12 },
  stats: { flexDirection: 'row', gap: 24, marginTop: 16 },
  stat: { alignItems: 'center' },
  statValue: { fontSize: 18, fontWeight: '700' },
  statLabel: { color: '#666', fontSize: 12 },
  sectionTitle: { fontSize: 16, fontWeight: '700', alignSelf: 'flex-start', marginTop: 24, marginLeft: 0 },
  empty: { color: '#666', textAlign: 'center', marginTop: 16 },
});
