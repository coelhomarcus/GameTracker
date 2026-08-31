import { memo } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { displayName } from '../lib/displayName';
import { formatRelativeTime } from '../lib/relativeTime';
import { colors, space, type } from '../theme';
import type { UserReply } from '../types/models';
import { Avatar } from './ui';

interface Author {
  name: string | null;
  username: string;
  avatarUrl: string | null;
}

interface Props {
  reply: UserReply;
  /** Quem escreveu a resposta — o dono do perfil que está sendo visto. */
  author: Author;
  onPress: () => void;
}

const AVATAR_SIZE = 40;

function ReplyThreadCardComponent({ reply, author, onPress }: Props) {
  const parentAuthor = reply.post.user;

  return (
    <Pressable
      style={({ pressed }) => [styles.card, pressed && styles.cardPressed]}
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={`Resposta de ${displayName(author)}`}
    >
      <View style={styles.row}>
        <View style={styles.avatarColumn}>
          <Avatar user={parentAuthor} size="lg" />
          <View style={styles.threadLine} />
        </View>
        <View style={[styles.body, styles.parentBody]}>
          <View style={styles.headerRow}>
            <Text style={styles.name}>{displayName(parentAuthor)}</Text>
            <Text style={styles.handle}>@{parentAuthor.username}</Text>
          </View>
          <Text style={styles.parentContent} numberOfLines={3}>
            {reply.post.content}
          </Text>
        </View>
      </View>

      <View style={styles.row}>
        <View style={styles.avatarColumn}>
          <Avatar user={author} size="lg" />
        </View>
        <View style={styles.body}>
          <View style={styles.headerRow}>
            <Text style={styles.name}>{displayName(author)}</Text>
            <Text style={styles.handle}>@{author.username}</Text>
            <Text style={styles.time}>· {formatRelativeTime(reply.createdAt)}</Text>
          </View>
          <Text style={styles.replyingTo}>
            Respondendo a <Text style={styles.replyingToHandle}>@{parentAuthor.username}</Text>
          </Text>
          <Text style={styles.replyContent}>{reply.content}</Text>
        </View>
      </View>
    </Pressable>
  );
}

export const ReplyThreadCard = memo(ReplyThreadCardComponent);

const styles = StyleSheet.create({
  card: {
    paddingHorizontal: space.lg,
    paddingVertical: space.lg,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  cardPressed: { backgroundColor: colors.surface },
  row: { flexDirection: 'row', gap: space.md },
  avatarColumn: { width: AVATAR_SIZE, alignItems: 'center' },
  // Liga o avatar do post original ao avatar da resposta.
  threadLine: {
    width: 2,
    flex: 1,
    backgroundColor: colors.border,
    marginTop: space.sm,
    marginBottom: -space.sm,
  },
  body: { flex: 1, gap: space.hair },
  parentBody: { paddingBottom: space.lg },
  headerRow: { flexDirection: 'row', alignItems: 'baseline', gap: space.xs, flexWrap: 'wrap' },
  name: { ...type.bodyStrong, color: colors.textPrimary },
  handle: { ...type.caption, color: colors.textSecondary },
  time: { ...type.dataSm, color: colors.textSecondary },
  parentContent: { ...type.caption, color: colors.textSecondary },
  replyingTo: { ...type.caption, color: colors.textSecondary },
  replyingToHandle: { color: colors.accent },
  replyContent: { ...type.body, color: colors.textPrimary, marginTop: space.hair },
});
