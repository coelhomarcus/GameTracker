import { and, eq, ne } from 'drizzle-orm';
import type { Server, Socket } from 'socket.io';
import { db } from '../db';
import { conversationParticipants, messages } from '../db/schema';
import { sendPushToUser } from '../push/pushService';

const userColumns = { id: true, username: true, name: true, avatarUrl: true } as const;

const MAX_MESSAGE_LENGTH = 2000;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Valida antes de consultar: um id que não é UUID faz o Postgres lançar, e um erro não tratado
 * dentro de um handler assíncrono derrubaria o processo inteiro. */
function isUuid(value: unknown): value is string {
  return typeof value === 'string' && UUID_PATTERN.test(value);
}

type Ack = (response: unknown) => void;

// Contagem de conexões por usuário (várias abas/dispositivos) — só emite offline quando chega a zero.
// Em memória por processo: presença fica por instância; se escalar o backend horizontalmente,
// isso precisaria migrar pra um contador compartilhado (ex: Redis).
const onlineConnections = new Map<string, number>();

function isOnline(userId: string) {
  return (onlineConnections.get(userId) ?? 0) > 0;
}

async function conversationRoomsFor(userId: string) {
  const participations = await db.query.conversationParticipants.findMany({
    where: eq(conversationParticipants.userId, userId),
    columns: { conversationId: true },
  });
  return participations.map((p) => `conversation:${p.conversationId}`);
}

async function findParticipants(conversationId: string) {
  return db.query.conversationParticipants.findMany({
    where: eq(conversationParticipants.conversationId, conversationId),
    columns: { userId: true },
  });
}

/**
 * Envolve um handler: nunca deixa uma exceção virar "unhandled rejection" (que mata o processo)
 * e sempre responde ao ACK, para o cliente não ficar esperando até o timeout.
 */
function safe<T>(event: string, handler: (payload: T, ack?: Ack) => Promise<void> | void) {
  return async (payload: T, ack?: Ack) => {
    try {
      await handler(payload, typeof ack === 'function' ? ack : undefined);
    } catch (err) {
      console.error(`[socket] erro em ${event}:`, err);
      if (typeof ack === 'function') ack({ error: 'Erro interno' });
    }
  };
}

/** Regista os listeners de forma síncrona, antes de qualquer await — senão eventos emitidos
 * logo após o "connect" do cliente podem chegar antes do listener existir e são perdidos. */
export function registerChatHandlers(io: Server, socket: Socket) {
  const userId = socket.data.userId as string;

  // A presença é contada de forma síncrona, antes de qualquer await: contar depois deixava uma
  // janela em que um disconnect imediato decrementava um valor que ainda não tinha sido somado.
  const wasOffline = !isOnline(userId);
  onlineConnections.set(userId, (onlineConnections.get(userId) ?? 0) + 1);

  async function requireParticipant(conversationId: unknown) {
    if (!isUuid(conversationId)) return false;
    const participant = await db.query.conversationParticipants.findFirst({
      where: and(
        eq(conversationParticipants.conversationId, conversationId),
        eq(conversationParticipants.userId, userId),
      ),
    });
    return participant != null;
  }

  socket.on(
    'conversation:join',
    safe('conversation:join', async (payload: { conversationId?: unknown }, ack) => {
      const conversationId = payload?.conversationId;
      if (!isUuid(conversationId)) return ack?.({ error: 'conversationId inválido' });
      if (!(await requireParticipant(conversationId))) return ack?.({ error: 'Conversa não encontrada' });

      await socket.join(`conversation:${conversationId}`);
      ack?.({ ok: true });
    }),
  );

  socket.on('conversation:leave', (payload: { conversationId?: unknown }) => {
    if (isUuid(payload?.conversationId)) socket.leave(`conversation:${payload.conversationId}`);
  });

  socket.on(
    'message:send',
    safe(
      'message:send',
      async (payload: { conversationId?: unknown; content?: unknown; clientMessageId?: unknown }, ack) => {
        const { conversationId, content, clientMessageId } = payload ?? {};
        if (!isUuid(conversationId) || typeof content !== 'string') return ack?.({ error: 'Payload inválido' });
        const text = content.trim();
        if (!text || text.length > MAX_MESSAGE_LENGTH) return ack?.({ error: 'Payload inválido' });
        // Opcional: o cliente legado não envia. Se vier, precisa ser um UUID.
        if (clientMessageId !== undefined && clientMessageId !== null && !isUuid(clientMessageId)) {
          return ack?.({ error: 'clientMessageId inválido' });
        }
        const cid = isUuid(clientMessageId) ? clientMessageId : undefined;

        if (!(await requireParticipant(conversationId))) return ack?.({ error: 'Conversa não encontrada' });

        // Idempotente por (conversa, remetente, clientMessageId): repetir o envio — por exemplo,
        // porque o ACK se perdeu — devolve a mensagem já gravada, sem criar outra, sem novo evento
        // e sem novo push.
        const inserted = await db
          .insert(messages)
          .values({ conversationId, senderId: userId, content: text, clientMessageId: cid })
          .onConflictDoNothing()
          .returning({ id: messages.id });

        if (inserted.length === 0 && cid) {
          const existing = await db.query.messages.findFirst({
            where: and(
              eq(messages.conversationId, conversationId),
              eq(messages.senderId, userId),
              eq(messages.clientMessageId, cid),
            ),
            with: { sender: { columns: userColumns } },
          });
          return ack?.(existing ? { message: existing } : { error: 'Erro interno' });
        }

        const message = await db.query.messages.findFirst({
          where: eq(messages.id, inserted[0]!.id),
          with: { sender: { columns: userColumns } },
        });

        io.to(`conversation:${conversationId}`).emit('message:receive', message);
        ack?.({ message });

        const others = await db.query.conversationParticipants.findMany({
          where: and(
            eq(conversationParticipants.conversationId, conversationId),
            ne(conversationParticipants.userId, userId),
          ),
          columns: { userId: true },
        });
        for (const other of others) {
          void sendPushToUser(other.userId, {
            title: message!.sender.username,
            // Clientes novos: texto genérico (o app busca a mensagem já autenticado). O cliente
            // legado (Expo) segue recebendo o texto, como sempre recebeu.
            body: 'Nova mensagem',
            expoBody: text,
            data: { type: 'message', recipientId: other.userId, conversationId, messageId: message!.id },
          });
        }
      },
    ),
  );

  // Digitação: só vale para quem já entrou na sala da conversa (e portanto é participante).
  // `socket.to(sala)` não exige estar na sala, então sem esta checagem qualquer usuário
  // autenticado poderia emitir digitação para a conversa de outras pessoas.
  const relayTyping = (event: 'typing:start' | 'typing:stop') => (payload: { conversationId?: unknown }) => {
    const conversationId = payload?.conversationId;
    if (!isUuid(conversationId)) return;
    const room = `conversation:${conversationId}`;
    if (!socket.rooms.has(room)) return;
    socket.to(room).emit(event, { conversationId, userId });
  };
  socket.on('typing:start', relayTyping('typing:start'));
  socket.on('typing:stop', relayTyping('typing:stop'));

  // Snapshot de presença: quem da conversa está conectado agora. Só para participantes. Vale
  // para esta instância do backend (ver nota sobre `onlineConnections`).
  socket.on(
    'presence:get',
    safe('presence:get', async (payload: { conversationId?: unknown }, ack) => {
      const conversationId = payload?.conversationId;
      if (!isUuid(conversationId)) return ack?.({ error: 'conversationId inválido' });
      if (!(await requireParticipant(conversationId))) return ack?.({ error: 'Conversa não encontrada' });

      const participants = await findParticipants(conversationId);
      ack?.({ online: participants.map((p) => p.userId).filter((id) => id !== userId && isOnline(id)) });
    }),
  );

  socket.on('disconnect', () => {
    const remaining = (onlineConnections.get(userId) ?? 1) - 1;
    if (remaining > 0) {
      onlineConnections.set(userId, remaining);
      return;
    }
    onlineConnections.delete(userId);
    // Consulta as conversas de agora (e não as de quando conectou): conversas criadas depois também recebem o aviso.
    void conversationRoomsFor(userId)
      .then((rooms) => rooms.forEach((room) => io.to(room).emit('presence:offline', { userId })))
      .catch((err) => console.error('[socket] erro ao avisar presença offline:', err));
  });

  if (wasOffline) {
    void conversationRoomsFor(userId)
      .then((rooms) => rooms.forEach((room) => socket.to(room).emit('presence:online', { userId })))
      .catch((err) => console.error('[socket] erro ao avisar presença online:', err));
  }
}
