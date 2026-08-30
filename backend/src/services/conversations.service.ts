import { AppError } from '../lib/errors';
import { prisma } from '../lib/prisma';

const userSelect = { id: true, username: true, avatarUrl: true } as const;

export async function listMine(userId: string) {
  const participations = await prisma.conversationParticipant.findMany({
    where: { userId },
    include: {
      conversation: {
        include: {
          participants: { include: { user: { select: userSelect } } },
          messages: { orderBy: { createdAt: 'desc' }, take: 1 },
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
  const candidate = await prisma.conversation.findFirst({
    where: {
      AND: [{ participants: { some: { userId } } }, { participants: { some: { userId: otherUserId } } }],
    },
    include: { participants: true },
  });

  return candidate && candidate.participants.length === 2 ? candidate : null;
}

export async function findOrCreateWithUser(userId: string, otherUserId: string) {
  if (userId === otherUserId) {
    throw new AppError(400, 'invalid_operation', 'Não é possível iniciar uma conversa consigo mesmo');
  }

  const otherUser = await prisma.user.findUnique({ where: { id: otherUserId } });
  if (!otherUser) throw new AppError(404, 'not_found', 'Usuário não encontrado');

  const existing = await findExistingConversation(userId, otherUserId);
  if (existing) return { id: existing.id };

  const created = await prisma.conversation.create({
    data: { participants: { create: [{ userId }, { userId: otherUserId }] } },
  });
  return { id: created.id };
}

async function requireParticipant(userId: string, conversationId: string) {
  const participant = await prisma.conversationParticipant.findUnique({
    where: { conversationId_userId: { conversationId, userId } },
  });
  if (!participant) throw new AppError(404, 'not_found', 'Conversa não encontrada');
  return participant;
}

export async function getMessages(userId: string, conversationId: string, cursor: string | undefined, limit: number) {
  await requireParticipant(userId, conversationId);

  const messages = await prisma.message.findMany({
    where: { conversationId },
    orderBy: { createdAt: 'desc' },
    take: limit + 1,
    ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    include: { sender: { select: userSelect } },
  });

  const hasMore = messages.length > limit;
  const items = messages.slice(0, limit);
  const nextCursor = hasMore ? items[items.length - 1]?.id : null;

  return { items, nextCursor };
}

export async function markRead(userId: string, conversationId: string) {
  const participant = await requireParticipant(userId, conversationId);
  await prisma.conversationParticipant.update({ where: { id: participant.id }, data: { lastReadAt: new Date() } });
}
