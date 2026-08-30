import { useNavigation, useRoute, type RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';
import * as conversationsApi from '../api/conversations';
import * as usersApi from '../api/users';
import { useAuthStore } from '../store/authStore';
import type { RootStackParamList } from '../navigation/types';

export default function UserProfileScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<RouteProp<RootStackParamList, 'UserProfile'>>();
  const { userId } = route.params;
  const myId = useAuthStore((state) => state.user?.id);
  const queryClient = useQueryClient();

  const profileQuery = useQuery({
    queryKey: ['user-profile', userId],
    queryFn: () => usersApi.getPublicProfile(userId),
  });

  const followMutation = useMutation({
    mutationFn: () => (profileQuery.data?.isFollowedByMe ? usersApi.unfollow(userId) : usersApi.follow(userId)),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['user-profile', userId] }),
  });

  const messageMutation = useMutation({
    mutationFn: () => conversationsApi.createOrGetConversation(userId),
    onSuccess: (conversation) => {
      navigation.navigate('ChatRoom', { conversationId: conversation.id, otherUsername: profileQuery.data!.username });
    },
  });

  if (profileQuery.isLoading || !profileQuery.data) {
    return (
      <View style={styles.center}>
        <ActivityIndicator />
      </View>
    );
  }

  const profile = profileQuery.data;
  const isMe = myId === userId;

  return (
    <View style={styles.container}>
      <View style={styles.avatar}>
        <Text style={styles.avatarText}>{profile.username[0]?.toUpperCase()}</Text>
      </View>
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
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  container: { flex: 1, alignItems: 'center', padding: 24, gap: 4 },
  avatar: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: '#4f46e5',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
  },
  avatarText: { color: '#fff', fontSize: 28, fontWeight: '700' },
  username: { fontSize: 20, fontWeight: '700' },
  bio: { color: '#666', textAlign: 'center', marginTop: 4 },
  stats: { flexDirection: 'row', gap: 24, marginVertical: 20 },
  stat: { alignItems: 'center' },
  statValue: { fontSize: 18, fontWeight: '700' },
  statLabel: { color: '#666', fontSize: 12 },
  actions: { flexDirection: 'row', gap: 12 },
  button: { backgroundColor: '#4f46e5', borderRadius: 8, paddingVertical: 10, paddingHorizontal: 24 },
  buttonFollowing: { backgroundColor: 'transparent', borderWidth: 1, borderColor: '#4f46e5' },
  buttonText: { color: '#fff', fontWeight: '600' },
  buttonTextFollowing: { color: '#4f46e5' },
});
