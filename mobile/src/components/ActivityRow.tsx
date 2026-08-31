import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { memo } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { displayName } from '../lib/displayName';
import { STATUS_COLOR, STATUS_ICON } from '../lib/gameEntryLabels';
import { formatRelativeTime } from '../lib/relativeTime';
import type { RootStackParamList } from '../navigation/types';
import { colors, hit, icon, opacity, radius, space, type } from '../theme';
import type { Post } from '../types/models';
import { RemoteImage } from './ui';

interface Props {
  post: Post;
  onPress: () => void;
  onAuthorPress: () => void;
  onToggleLike: () => void;
}

const BADGE_SIZE = 34;
const BADGE_ICON_SIZE = 17;
const COVER_WIDTH = 28;
const COVER_HEIGHT = 37;

/**
 * Linha compacta pra `post.type === 'activity'`, no estilo dos ícones de
 * notificação da X: um badge colorido lidera a linha (no lugar de um avatar),
 * a capa do jogo vira miniatura secundária. A cor/ícone vêm de
 * `post.activityStatus` — o snapshot imutável tirado na criação do post
 * (nunca de `gameEntry.status`, que é o status ATUAL e mutável do
 * playthrough e faria o ícone de um post antigo mudar sozinho).
 */
function ActivityRowComponent({ post, onPress, onAuthorPress, onToggleLike }: Props) {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const badgeColor = post.activityStatus ? STATUS_COLOR[post.activityStatus] : colors.textTertiary;
  const badgeIcon = post.activityStatus ? STATUS_ICON[post.activityStatus] : 'game-controller-outline';
  const taggedGame = post.gameEntry?.game ?? post.game;

  return (
    <Pressable style={({ pressed }) => [styles.row, pressed && styles.rowPressed]} onPress={onPress}>
      <View style={[styles.badge, { backgroundColor: badgeColor }]}>
        <Ionicons name={badgeIcon} size={BADGE_ICON_SIZE} color={colors.textOnStatus} />
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

            {/* Sempre visível — comentar em post de atividade já funciona de
                ponta a ponta, só a UI compacta escondia a affordance. */}
            <Pressable
              onPress={onPress}
              hitSlop={hit.sm}
              accessibilityRole="button"
              accessibilityLabel={`${post.commentCount} comentários`}
              style={({ pressed }) => [styles.actionButton, pressed && { opacity: opacity.pressed }]}
            >
              <Ionicons name="chatbubble-outline" size={icon.xs} color={colors.textTertiary} />
              <Text style={styles.actionText}>{post.commentCount}</Text>
            </Pressable>
          </View>
        </View>
      </View>

      {taggedGame && (
        <Pressable
          onPress={() => navigation.navigate('GameFocus', { igdbId: taggedGame.igdbId })}
          accessibilityRole="button"
          accessibilityLabel={`Ver ${taggedGame.name}`}
          style={({ pressed }) => pressed && { opacity: opacity.pressed }}
        >
          <RemoteImage uri={taggedGame.coverUrl} style={styles.cover} />
        </Pressable>
      )}
    </Pressable>
  );
}

export const ActivityRow = memo(ActivityRowComponent);

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: space.md,
    backgroundColor: colors.surface,
    paddingVertical: space.sm,
    paddingHorizontal: space.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  rowPressed: { backgroundColor: colors.surfaceRaised },
  badge: {
    width: BADGE_SIZE,
    height: BADGE_SIZE,
    borderRadius: radius.pill,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cover: { width: COVER_WIDTH, height: COVER_HEIGHT, borderRadius: radius.xs, backgroundColor: colors.skeleton },
  body: { flex: 1, gap: space.xs },
  line: { ...type.caption },
  author: { ...type.label, color: colors.textPrimary },
  content: { ...type.caption, color: colors.textSecondary },
  footer: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  time: { ...type.dataSm, color: colors.textTertiary },
  actions: { flexDirection: 'row', gap: space.md },
  actionButton: { flexDirection: 'row', alignItems: 'center', gap: space.hair },
  actionText: { ...type.dataSm, color: colors.textTertiary },
});
