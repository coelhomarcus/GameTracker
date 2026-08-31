import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { displayName } from '../lib/displayName';
import { formatRelativeTime } from '../lib/relativeTime';
import { colors } from '../theme/colors';
import type { UserReply } from '../types/models';

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

function Avatar({ user }: { user: Author }) {
  if (user.avatarUrl) return <Image source={{ uri: user.avatarUrl }} style={styles.avatarImage} />;
  return (
    <View style={styles.avatarFallback}>
      <Text style={styles.avatarText}>{displayName(user)[0]?.toUpperCase()}</Text>
    </View>
  );
}

export function ReplyThreadCard({ reply, author, onPress }: Props) {
  const parentAuthor = reply.post.user;

  return (
    <Pressable style={styles.card} onPress={onPress}>
      <View style={styles.row}>
        <View style={styles.avatarColumn}>
          <Avatar user={parentAuthor} />
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
          <Avatar user={author} />
        </View>
        <View style={styles.body}>
          <View style={styles.headerRow}>
            <Text style={styles.name}>{displayName(author)}</Text>
            <Text style={styles.handle}>@{author.username}</Text>
            <Text style={styles.handle}>· {formatRelativeTime(reply.createdAt)}</Text>
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

const AVATAR_SIZE = 36;

const styles = StyleSheet.create({
  card: { paddingHorizontal: 16, paddingTop: 14, paddingBottom: 16, borderBottomWidth: 1, borderBottomColor: colors.border },
  row: { flexDirection: 'row', gap: 12 },
  avatarColumn: { width: AVATAR_SIZE, alignItems: 'center' },
  avatarImage: { width: AVATAR_SIZE, height: AVATAR_SIZE, borderRadius: AVATAR_SIZE / 2 },
  avatarFallback: {
    width: AVATAR_SIZE,
    height: AVATAR_SIZE,
    borderRadius: AVATAR_SIZE / 2,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: { color: '#fff', fontWeight: '700', fontSize: 14 },
  // Liga o avatar do post original ao avatar da resposta, como a thread da X.
  threadLine: { width: 2, flex: 1, backgroundColor: colors.border, marginTop: 6, marginBottom: -6 },
  body: { flex: 1, gap: 2 },
  parentBody: { paddingBottom: 14 },
  headerRow: { flexDirection: 'row', alignItems: 'baseline', gap: 4, flexWrap: 'wrap' },
  name: { fontWeight: '700', color: colors.textPrimary, fontSize: 14 },
  handle: { color: colors.textSecondary, fontSize: 13 },
  parentContent: { color: colors.textSecondary, fontSize: 14, lineHeight: 19 },
  replyingTo: { color: colors.textSecondary, fontSize: 12, marginTop: 1 },
  replyingToHandle: { color: colors.accent },
  replyContent: { color: colors.textPrimary, fontSize: 15, lineHeight: 20, marginTop: 3 },
});
