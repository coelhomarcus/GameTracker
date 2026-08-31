import { and, desc, eq, exists, sql } from 'drizzle-orm';
import { db } from '../db';
import { conversationParticipants, conversations, messages, users } from '../db/schema';
import { AppError } from '../lib/errors';
import { decodeCursor, encodeCursor } from '../lib/cursor';

const userColumns = { id: true, username: true, name: true, avatarUrl: true } as const;

export async function listMine(userId: string) {
  const participations = await db.query.conversationParticipants.findMany({
    where: eq(conversationParticipants.userId, userId),
    with: {
      conversation: {
        with: {
          participants: { with: { user: { columns: userColumns } } },
          messages: { orderBy: desc(messages.createdAt), limit: 1 },
        },
      },
    },
  });

  return participations
    .map((p) => {
      const conversation = p.conversation;
      const otherUser = conversation.participants.find((cp) => cp.userId !== userId)?.user ?? null;
      const lastMessage = conversation.messages[0] ?? null;
      const unread = lastMessage ? !p.lastReadAt || lastMessage.createdAt > p.lastReadAt : false;

      return { id: conversation.id, otherUser, lastMessage, unread };
    })
    .sort((a, b) => {
      const aTime = a.lastMessage?.createdAt.getTime() ?? 0;
      const bTime = b.lastMessage?.createdAt.getTime() ?? 0;
      return bTime - aTime;
    });
}

async function findExistingConversation(userId: string, otherUserId: string) {
  const candidates = await db.query.conversations.findMany({
    where: and(
      exists(
        db
          .select()
          .from(conversationParticipants)
          .where(
            and(eq(conversationParticipants.conversationId, conversations.id), eq(conversationParticipants.userId, userId)),
          ),
      ),
      exists(
        db
          .select()
          .from(conversationParticipants)
          .where(
            and(
              eq(conversationParticipants.conversationId, conversations.id),
              eq(conversationParticipants.userId, otherUserId),
            ),
          ),
      ),
    ),
    with: { participants: true },
  });

  return candidates.find((c) => c.participants.length === 2) ?? null;
}

export async function findOrCreateWithUser(userId: string, otherUserId: string) {
  if (userId === otherUserId) {
    throw new AppError(400, 'invalid_operation', 'Não é possível iniciar uma conversa consigo mesmo');
  }

  const otherUser = await db.query.users.findFirst({ where: eq(users.id, otherUserId) });
  if (!otherUser) throw new AppError(404, 'not_found', 'Usuário não encontrado');

  const existing = await findExistingConversation(userId, otherUserId);
  if (existing) return { id: existing.id };

  return db.transaction(async (tx) => {
    const [conversation] = await tx.insert(conversations).values({}).returning();
    await tx.insert(conversationParticipants).values([
      { conversationId: conversation!.id, userId },
      { conversationId: conversation!.id, userId: otherUserId },
    ]);
    return { id: conversation!.id };
  });
}

async function requireParticipant(userId: string, conversationId: string) {
  const participant = await db.query.conversationParticipants.findFirst({
    where: and(eq(conversationParticipants.conversationId, conversationId), eq(conversationParticipants.userId, userId)),
  });
  if (!participant) throw new AppError(404, 'not_found', 'Conversa não encontrada');
  return participant;
}

export async function getMessages(userId: string, conversationId: string, cursor: string | undefined, limit: number) {
  await requireParticipant(userId, conversationId);

  const cursorFilter = cursor
    ? (() => {
        const decoded = decodeCursor(cursor);
        return sql`(${messages.createdAt}, ${messages.id}) < (${decoded.createdAt.toISOString()}, ${decoded.id})`;
      })()
    : undefined;

  const results = await db.query.messages.findMany({
    where: cursorFilter
      ? and(eq(messages.conversationId, conversationId), cursorFilter)
      : eq(messages.conversationId, conversationId),
    orderBy: [desc(messages.createdAt), desc(messages.id)],
    limit: limit + 1,
    with: { sender: { columns: userColumns } },
  });

  const hasMore = results.length > limit;
  const items = results.slice(0, limit);
  const last = items[items.length - 1];
  const nextCursor = hasMore && last ? encodeCursor(last.createdAt, last.id) : null;

  return { items, nextCursor };
}

export async function markRead(userId: string, conversationId: string) {
  const participant = await requireParticipant(userId, conversationId);
  await db
    .update(conversationParticipants)
    .set({ lastReadAt: new Date() })
    .where(eq(conversationParticipants.id, participant.id));
}
