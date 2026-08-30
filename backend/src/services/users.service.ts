import { and, count, eq, ilike, ne, sql } from 'drizzle-orm';
import { db } from '../db';
import { follows, gameEntries, users } from '../db/schema';
import { AppError } from '../lib/errors';
import { getPublicBaseUrl } from '../lib/publicUrl';
import { deleteAvatarIfLocal, saveAvatar } from '../lib/uploads';
import * as notificationsService from './notifications.service';

export async function search(viewerId: string, term: string) {
  return db
    .select({
      id: users.id,
      username: users.username,
      avatarUrl: users.avatarUrl,
      bio: users.bio,
      isFollowedByMe: sql<boolean>`${follows.id} is not null`,
    })
    .from(users)
    .leftJoin(follows, and(eq(follows.followerId, viewerId), eq(follows.followingId, users.id)))
    .where(and(ilike(users.username, `%${term}%`), ne(users.id, viewerId)))
    .limit(20);
}

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

export async function updateProfile(userId: string, input: { bio?: string }) {
  await db.update(users).set(input).where(eq(users.id, userId));
}

export async function updateAvatar(userId: string, buffer: Buffer) {
  const current = await db.query.users.findFirst({ where: eq(users.id, userId), columns: { avatarUrl: true } });

  const relativePath = await saveAvatar(buffer);
  const avatarUrl = `${getPublicBaseUrl()}${relativePath}`;

  await db.update(users).set({ avatarUrl }).where(eq(users.id, userId));
  void deleteAvatarIfLocal(current?.avatarUrl ?? null);

  return avatarUrl;
}
