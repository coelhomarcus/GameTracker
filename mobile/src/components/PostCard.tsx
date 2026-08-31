import { Ionicons } from '@expo/vector-icons';
import { memo } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { displayName } from '../lib/displayName';
import { colors, hit, icon, opacity, radius, space, type } from '../theme';
import type { Post } from '../types/models';
import { LikeButton } from './LikeButton';
import { Avatar, RemoteImage } from './ui';

interface Props {
  post: Post;
  onPress: () => void;
  onAuthorPress: () => void;
  onToggleLike: () => void;
}

const AVATAR_SIZE = 44;
const ROW_GAP = space.md;

function PostCardComponent({ post, onPress, onAuthorPress, onToggleLike }: Props) {
  return (
    // Sem accessibilityRole aqui de propósito: o card contém avatar, like e
    // contador de comentários, cada um já com seu próprio role="button". Um
    // <button> não pode conter outro — no React Native Web isso vira <button>
    // aninhado, HTML inválido que o navegador corrige sozinho e quebra a
    // hidratação. O card continua tocável (onPress funciona sem o role), só
    // não é anunciado como botão pra leitor de tela — os controles reais
    // dentro dele são.
    <Pressable style={({ pressed }) => [styles.card, pressed && styles.cardPressed]} onPress={onPress}>
      {post.type === 'activity' && (
        <View style={styles.activityTag}>
          <Ionicons name="game-controller-outline" size={icon.xs} color={colors.textSecondary} />
          <Text style={styles.activityTagText}>Atividade</Text>
        </View>
      )}

      <View style={styles.row}>
        <Avatar user={post.user} size="xl" onPress={onAuthorPress} />

        <View style={styles.body}>
          <Pressable onPress={onAuthorPress} style={styles.headerRow} hitSlop={hit.sm}>
            <Text style={styles.username}>{displayName(post.user)}</Text>
            <Text style={styles.handle}>@{post.user.username}</Text>
          </Pressable>

          <Text style={styles.content}>{post.content}</Text>

          {post.gameEntry && (
            <View style={styles.gameTag}>
              {post.gameEntry.game.coverUrl ? (
                <RemoteImage uri={post.gameEntry.game.coverUrl} style={styles.gameTagCover} />
              ) : (
                <Ionicons name="game-controller-outline" size={icon.sm} color={colors.accent} />
              )}
              <Text style={styles.gameTagText}>
                {post.gameEntry.game.name} · {post.gameEntry.platform}
              </Text>
            </View>
          )}

          <View style={styles.actions}>
            <LikeButton liked={post.likedByMe} count={post.likeCount} onPress={onToggleLike} />
            {/* Contagem de comentários abre o post, como o card inteiro. */}
            <Pressable
              onPress={onPress}
              hitSlop={hit.md}
              accessibilityRole="button"
              accessibilityLabel={`${post.commentCount} comentários`}
              style={({ pressed }) => [styles.actionButton, pressed && { opacity: opacity.pressed }]}
            >
              <Ionicons name="chatbubble-outline" size={icon.md} color={colors.textSecondary} />
              <Text style={styles.actionText}>{post.commentCount}</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Pressable>
  );
}

/** Linha de lista: memo só rende com renderItem estável na tela que a usa. */
export const PostCard = memo(PostCardComponent);

const styles = StyleSheet.create({
  card: {
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    paddingVertical: space.md,
    paddingHorizontal: space.md,
    gap: space.xs,
  },
  cardPressed: { backgroundColor: colors.surface },
  activityTag: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: space.xs,
    marginLeft: AVATAR_SIZE + ROW_GAP,
    marginBottom: space.hair,
  },
  activityTagText: { ...type.micro, color: colors.textSecondary },
  row: { flexDirection: 'row', gap: ROW_GAP },
  body: { flex: 1, gap: space.xs },
  headerRow: { flexDirection: 'row', alignItems: 'baseline', gap: space.xs },
  username: { ...type.bodyStrong, color: colors.textPrimary },
  handle: { ...type.caption, color: colors.textSecondary },
  content: { ...type.body, color: colors.textPrimary },
  gameTag: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: space.sm,
    backgroundColor: colors.surface,
    borderRadius: radius.sm,
    padding: space.sm,
    alignSelf: 'flex-start',
  },
  gameTagCover: { width: 40, height: 53, borderRadius: radius.xs },
  gameTagText: { ...type.caption, color: colors.accent },
  actions: { flexDirection: 'row', gap: space.lg, marginTop: space.xs },
  actionButton: { flexDirection: 'row', alignItems: 'center', gap: space.xs },
  actionText: { ...type.dataSm, color: colors.textSecondary },
});
