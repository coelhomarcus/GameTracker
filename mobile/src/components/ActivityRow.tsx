import { Ionicons } from '@expo/vector-icons';
import { memo } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { displayName } from '../lib/displayName';
import { formatRelativeTime } from '../lib/relativeTime';
import { colors, hit, icon, opacity, radius, space, type } from '../theme';
import type { Post } from '../types/models';
import { Avatar, RemoteImage, StatusBadge } from './ui';

interface Props {
  post: Post;
  onPress: () => void;
  onAuthorPress: () => void;
  onToggleLike: () => void;
}

const COVER_WIDTH = 32;
const COVER_HEIGHT = 42;

/**
 * Linha compacta pra `post.type === 'activity'` (sempre criado com gameEntry
 * pelo backend — ver `createActivityPost` em gameEntries.service.ts), no
 * estilo do feed de atividade da Steam: capa pequena, frase pronta que já vem
 * do servidor, hora relativa — sem o peso visual de um post escrito.
 */
function ActivityRowComponent({ post, onPress, onAuthorPress, onToggleLike }: Props) {
  const entry = post.gameEntry;

  return (
    <Pressable style={({ pressed }) => [styles.row, pressed && styles.rowPressed]} onPress={onPress}>
      <View style={styles.coverWrap}>
        {entry && <RemoteImage uri={entry.game.coverUrl} style={styles.cover} />}
        {entry && <StatusBadge status={entry.status} variant="dot" />}
      </View>

      <View style={styles.body}>
        <Text style={styles.line}>
          <Text style={styles.author} onPress={onAuthorPress}>
            {displayName(post.user)}
          </Text>{' '}
          <Text style={styles.content}>{post.content}</Text>
        </Text>

        <View style={styles.footer}>
          <Text style={styles.time}>{formatRelativeTime(post.createdAt)}</Text>

          <View style={styles.actions}>
            <Pressable
              onPress={onToggleLike}
              hitSlop={hit.sm}
              accessibilityRole="button"
              accessibilityLabel={post.likedByMe ? 'Descurtir' : 'Curtir'}
              accessibilityState={{ selected: post.likedByMe }}
              style={({ pressed }) => [styles.actionButton, pressed && { opacity: opacity.pressed }]}
            >
              <Ionicons
                name={post.likedByMe ? 'heart' : 'heart-outline'}
                size={icon.xs}
                color={post.likedByMe ? colors.like : colors.textTertiary}
              />
              {post.likeCount > 0 && <Text style={styles.actionText}>{post.likeCount}</Text>}
            </Pressable>

            {post.commentCount > 0 && (
              <View style={styles.actionButton}>
                <Ionicons name="chatbubble-outline" size={icon.xs} color={colors.textTertiary} />
                <Text style={styles.actionText}>{post.commentCount}</Text>
              </View>
            )}
          </View>
        </View>
      </View>
    </Pressable>
  );
}

export const ActivityRow = memo(ActivityRowComponent);

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    gap: space.md,
    backgroundColor: colors.surface,
    paddingVertical: space.sm,
    paddingHorizontal: space.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  rowPressed: { backgroundColor: colors.surfaceRaised },
  coverWrap: { width: COVER_WIDTH },
  cover: { width: COVER_WIDTH, height: COVER_HEIGHT, borderRadius: radius.xs, backgroundColor: colors.skeleton },
  body: { flex: 1, justifyContent: 'center', gap: space.xs },
  line: { ...type.caption },
  author: { ...type.label, color: colors.textPrimary },
  content: { ...type.caption, color: colors.textSecondary },
  footer: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  time: { ...type.dataSm, color: colors.textTertiary },
  actions: { flexDirection: 'row', gap: space.md },
  actionButton: { flexDirection: 'row', alignItems: 'center', gap: space.hair },
  actionText: { ...type.dataSm, color: colors.textTertiary },
});
