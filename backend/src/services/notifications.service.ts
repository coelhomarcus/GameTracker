import type { NotificationType } from '../generated/prisma/client';
import { prisma } from '../lib/prisma';
import { sendPushNotification } from '../lib/push';

const PUSH_MESSAGES: Record<NotificationType, (actor: string) => { title: string; body: string }> = {
  like: (actor) => ({ title: 'Nova curtida', body: `${actor} curtiu seu post` }),
  comment: (actor) => ({ title: 'Novo comentário', body: `${actor} comentou no seu post` }),
  follow: (actor) => ({ title: 'Novo seguidor', body: `${actor} começou a seguir você` }),
};

interface NotifyInput {
  userId: string;
  actorId: string;
  type: NotificationType;
  postId?: string;
}

/** Cria a notificação in-app e dispara o push (best-effort). Nunca notifica o próprio autor da ação. */
export async function notify({ userId, actorId, type, postId }: NotifyInput) {
  if (userId === actorId) return;

  const [notification, actor, recipient] = await Promise.all([
    prisma.notification.create({ data: { userId, actorId, type, postId } }),
    prisma.user.findUnique({ where: { id: actorId }, select: { username: true } }),
    prisma.user.findUnique({ where: { id: userId }, select: { expoPushToken: true } }),
  ]);

  if (actor && recipient?.expoPushToken) {
    const { title, body } = PUSH_MESSAGES[type](actor.username);
    void sendPushNotification(recipient.expoPushToken, title, body);
  }

  return notification;
}

export async function list(userId: string) {
  const [items, unreadCount] = await Promise.all([
    prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: { actor: { select: { id: true, username: true, avatarUrl: true } } },
    }),
    prisma.notification.count({ where: { userId, read: false } }),
  ]);

  return { items, unreadCount };
}

export async function markAllRead(userId: string) {
  await prisma.notification.updateMany({ where: { userId, read: false }, data: { read: true } });
}
