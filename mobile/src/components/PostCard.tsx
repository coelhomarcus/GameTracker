import { Ionicons } from '@expo/vector-icons';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { displayName } from '../lib/displayName';
import { colors } from '../theme/colors';
import { LikeButton } from './LikeButton';
import type { Post } from '../types/models';

interface Props {
  post: Post;
  onPress: () => void;
  onAuthorPress: () => void;
  onToggleLike: () => void;
}

const AVATAR_SIZE = 44;
const ROW_GAP = 10;

export function PostCard({ post, onPress, onAuthorPress, onToggleLike }: Props) {
  return (
    <Pressable style={styles.card} onPress={onPress}>
      {post.type === 'activity' && (
        <View style={styles.activityTag}>
          <Ionicons name="game-controller-outline" size={12} color={colors.textSecondary} />
          <Text style={styles.activityTagText}>Atividade</Text>
        </View>
      )}

      <View style={styles.row}>
        <Pressable onPress={onAuthorPress}>
          {post.user.avatarUrl ? (
            <Image source={{ uri: post.user.avatarUrl }} style={styles.avatarImage} />
          ) : (
            <View style={styles.avatar}>
              <Text style={styles.avatarText}>{displayName(post.user)[0]?.toUpperCase()}</Text>
            </View>
          )}
        </Pressable>

        <View style={styles.body}>
          <Pressable onPress={onAuthorPress} style={styles.headerRow}>
            <Text style={styles.username}>{displayName(post.user)}</Text>
            <Text style={styles.handle}>@{post.user.username}</Text>
          </Pressable>

          <Text style={styles.content}>{post.content}</Text>

          {post.gameEntry && (
            <View style={styles.gameTag}>
              {post.gameEntry.game.coverUrl ? (
                <Image source={{ uri: post.gameEntry.game.coverUrl }} style={styles.gameTagCover} />
              ) : (
                <Ionicons name="game-controller-outline" size={14} color={colors.accent} />
              )}
              <Text style={styles.gameTagText}>
                {post.gameEntry.game.name} · {post.gameEntry.platform}
              </Text>
            </View>
          )}

          <View style={styles.actions}>
            <LikeButton liked={post.likedByMe} count={post.likeCount} onPress={onToggleLike} />
            <View style={styles.actionButton}>
              <Ionicons name="chatbubble-outline" size={16} color={colors.textSecondary} />
              <Text style={styles.actionText}>{post.commentCount}</Text>
            </View>
          </View>
        </View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { borderBottomWidth: 1, borderBottomColor: colors.border, paddingVertical: 12, paddingHorizontal: 12, gap: 6 },
  activityTag: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginLeft: AVATAR_SIZE + ROW_GAP,
    marginBottom: 2,
  },
  activityTagText: { fontSize: 11, color: colors.textSecondary, fontWeight: '600' },
  row: { flexDirection: 'row', gap: ROW_GAP },
  avatar: {
    width: AVATAR_SIZE,
    height: AVATAR_SIZE,
    borderRadius: AVATAR_SIZE / 2,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: { color: '#fff', fontWeight: '700', fontSize: 18 },
  avatarImage: { width: AVATAR_SIZE, height: AVATAR_SIZE, borderRadius: AVATAR_SIZE / 2 },
  body: { flex: 1, gap: 4 },
  headerRow: { flexDirection: 'row', alignItems: 'baseline', gap: 4 },
  username: { fontWeight: '600', color: colors.textPrimary },
  handle: { color: colors.textSecondary, fontSize: 13 },
  content: { fontSize: 15, lineHeight: 20, color: colors.textPrimary },
  gameTag: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: colors.backgroundElevated,
    borderRadius: 8,
    padding: 8,
    alignSelf: 'flex-start',
  },
  gameTagCover: { width: 40, height: 53, borderRadius: 4 },
  gameTagText: { color: colors.accent, fontSize: 13 },
  actions: { flexDirection: 'row', gap: 16, marginTop: 4 },
  actionButton: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  actionText: { color: colors.textSecondary },
});
