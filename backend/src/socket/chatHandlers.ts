import { and, eq, ne } from 'drizzle-orm';
import type { Server, Socket } from 'socket.io';
import { db } from '../db';
import { conversationParticipants, messages } from '../db/schema';
import { sendPushNotification } from '../lib/push';

const userColumns = { id: true, username: true, avatarUrl: true } as const;

// Contagem de conexões por usuário (várias abas/dispositivos) — só emite offline quando chega a zero.
// Em memória por processo: presença fica por instância; se escalar o backend horizontalmente,
// isso precisaria migrar pra um contador compartilhado (ex: Redis).
const onlineConnections = new Map<string, number>();

async function conversationRoomsFor(userId: string) {
  const participations = await db.query.conversationParticipants.findMany({
    where: eq(conversationParticipants.userId, userId),
    columns: { conversationId: true },
  });
  return participations.map((p) => `conversation:${p.conversationId}`);
}

/** Regista os listeners de forma síncrona, antes de qualquer await — senão eventos emitidos
 * logo após o "connect" do cliente podem chegar antes do listener existir e são perdidos. */
export function registerChatHandlers(io: Server, socket: Socket) {
  const userId = socket.data.userId as string;
  let presenceRooms: string[] = [];

  socket.on('conversation:join', async (payload: { conversationId?: string }, ack?: (res: unknown) => void) => {
    const conversationId = payload?.conversationId;
    if (!conversationId) return ack?.({ error: 'conversationId obrigatório' });

    const participant = await db.query.conversationParticipants.findFirst({
      where: and(
        eq(conversationParticipants.conversationId, conversationId),
        eq(conversationParticipants.userId, userId),
      ),
    });
    if (!participant) return ack?.({ error: 'Conversa não encontrada' });

    socket.join(`conversation:${conversationId}`);
    ack?.({ ok: true });
  });

  socket.on('conversation:leave', (payload: { conversationId?: string }) => {
    if (payload?.conversationId) socket.leave(`conversation:${payload.conversationId}`);
  });

  socket.on(
    'message:send',
    async (payload: { conversationId?: string; content?: string }, ack?: (res: unknown) => void) => {
      const { conversationId, content } = payload ?? {};
      if (!conversationId || typeof content !== 'string' || !content.trim() || content.length > 2000) {
        return ack?.({ error: 'Payload inválido' });
      }

      const participant = await db.query.conversationParticipants.findFirst({
        where: and(
          eq(conversationParticipants.conversationId, conversationId),
          eq(conversationParticipants.userId, userId),
        ),
      });
      if (!participant) return ack?.({ error: 'Conversa não encontrada' });

      const [created] = await db
        .insert(messages)
        .values({ conversationId, senderId: userId, content: content.trim() })
        .returning();
      const message = await db.query.messages.findFirst({
        where: eq(messages.id, created!.id),
        with: { sender: { columns: userColumns } },
      });

      io.to(`conversation:${conversationId}`).emit('message:receive', message);
      ack?.({ message });

      const others = await db.query.conversationParticipants.findMany({
        where: and(
          eq(conversationParticipants.conversationId, conversationId),
          ne(conversationParticipants.userId, userId),
        ),
        with: { user: { columns: { expoPushToken: true } } },
      });
      for (const other of others) {
        void sendPushNotification(other.user.expoPushToken, message!.sender.username, content.trim());
      }
    },
  );

  socket.on('typing:start', (payload: { conversationId?: string }) => {
    if (payload?.conversationId) {
      socket.to(`conversation:${payload.conversationId}`).emit('typing:start', {
        conversationId: payload.conversationId,
        userId,
      });
    }
  });

  socket.on('typing:stop', (payload: { conversationId?: string }) => {
    if (payload?.conversationId) {
      socket.to(`conversation:${payload.conversationId}`).emit('typing:stop', {
        conversationId: payload.conversationId,
        userId,
      });
    }
  });

  socket.on('disconnect', () => {
    const remaining = (onlineConnections.get(userId) ?? 1) - 1;
    if (remaining <= 0) {
      onlineConnections.delete(userId);
      presenceRooms.forEach((room) => socket.to(room).emit('presence:offline', { userId }));
    } else {
      onlineConnections.set(userId, remaining);
    }
  });

  // Presença: não bloqueia o registro dos listeners acima, só dispara o broadcast quando a query terminar.
  void (async () => {
    presenceRooms = await conversationRoomsFor(userId);
    const wasOffline = (onlineConnections.get(userId) ?? 0) === 0;
    onlineConnections.set(userId, (onlineConnections.get(userId) ?? 0) + 1);
    if (wasOffline) {
      presenceRooms.forEach((room) => socket.to(room).emit('presence:online', { userId }));
    }
  })();
}
