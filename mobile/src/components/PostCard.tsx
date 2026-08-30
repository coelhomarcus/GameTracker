import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { Post } from '../types/models';

interface Props {
  post: Post;
  onPress: () => void;
  onAuthorPress: () => void;
  onToggleLike: () => void;
}

export function PostCard({ post, onPress, onAuthorPress, onToggleLike }: Props) {
  return (
    <Pressable style={styles.card} onPress={onPress}>
      <Pressable style={styles.header} onPress={onAuthorPress}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>{post.user.username[0]?.toUpperCase()}</Text>
        </View>
        <Text style={styles.username}>{post.user.username}</Text>
      </Pressable>

      <Text style={styles.content}>{post.content}</Text>

      {post.gameEntry && (
        <View style={styles.gameTag}>
          <Text style={styles.gameTagText}>
            🎮 {post.gameEntry.game.name} · {post.gameEntry.platform}
          </Text>
        </View>
      )}

      <View style={styles.actions}>
        <Pressable style={styles.actionButton} onPress={onToggleLike}>
          <Text style={[styles.actionText, post.likedByMe && styles.actionTextActive]}>
            {post.likedByMe ? '♥' : '♡'} {post.likeCount}
          </Text>
        </Pressable>
        <Text style={styles.actionText}>💬 {post.commentCount}</Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { borderWidth: 1, borderColor: '#eee', borderRadius: 10, padding: 12, gap: 8 },
  header: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#4f46e5',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: { color: '#fff', fontWeight: '700', fontSize: 14 },
  username: { fontWeight: '600' },
  content: { fontSize: 15, lineHeight: 20 },
  gameTag: { backgroundColor: '#eef2ff', borderRadius: 8, padding: 8, alignSelf: 'flex-start' },
  gameTagText: { color: '#4f46e5', fontSize: 13 },
  actions: { flexDirection: 'row', gap: 16, marginTop: 4 },
  actionButton: {},
  actionText: { color: '#666' },
  actionTextActive: { color: '#dc2626' },
});
