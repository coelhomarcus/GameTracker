import { and, count, eq } from 'drizzle-orm';
import { db } from '../db';
import { follows, gameEntries, users } from '../db/schema';
import { AppError } from '../lib/errors';
import * as notificationsService from './notifications.service';

export async function getPublicProfile(viewerId: string, targetId: string) {
  const user = await db.query.users.findFirst({
    where: eq(users.id, targetId),
    columns: { id: true, username: true, avatarUrl: true, bio: true, createdAt: true },
  });
  if (!user) throw new AppError(404, 'not_found', 'Usuário não encontrado');

  const [followerCountRows, followingCountRows, gameEntryCountRows, followRow] = await Promise.all([
    db.select({ value: count() }).from(follows).where(eq(follows.followingId, targetId)),
    db.select({ value: count() }).from(follows).where(eq(follows.followerId, targetId)),
    db.select({ value: count() }).from(gameEntries).where(eq(gameEntries.userId, targetId)),
    viewerId === targetId
      ? null
      : db.query.follows.findFirst({
          where: and(eq(follows.followerId, viewerId), eq(follows.followingId, targetId)),
        }),
  ]);

  return {
    ...user,
    followerCount: followerCountRows[0]!.value,
    followingCount: followingCountRows[0]!.value,
    gameEntryCount: gameEntryCountRows[0]!.value,
    isFollowedByMe: followRow != null,
  };
}

export async function follow(followerId: string, followingId: string) {
  if (followerId === followingId) {
    throw new AppError(400, 'invalid_operation', 'Não é possível seguir a si mesmo');
  }

  const target = await db.query.users.findFirst({ where: eq(users.id, followingId) });
  if (!target) throw new AppError(404, 'not_found', 'Usuário não encontrado');

  await db
    .insert(follows)
    .values({ followerId, followingId })
    .onConflictDoNothing({ target: [follows.followerId, follows.followingId] });

  await notificationsService.notify({ userId: followingId, actorId: followerId, type: 'follow' });
}

export async function unfollow(followerId: string, followingId: string) {
  await db.delete(follows).where(and(eq(follows.followerId, followerId), eq(follows.followingId, followingId)));
}

export async function setPushToken(userId: string, token: string) {
  await db.update(users).set({ expoPushToken: token }).where(eq(users.id, userId));
}
