import { AppError } from '../lib/errors';
import { prisma } from '../lib/prisma';
import * as notificationsService from './notifications.service';

export async function getPublicProfile(viewerId: string, targetId: string) {
  const user = await prisma.user.findUnique({
    where: { id: targetId },
    select: {
      id: true,
      username: true,
      avatarUrl: true,
      bio: true,
      createdAt: true,
      _count: { select: { followers: true, following: true, gameEntries: true } },
    },
  });
  if (!user) throw new AppError(404, 'not_found', 'Usuário não encontrado');

  const isFollowedByMe =
    viewerId === targetId
      ? false
      : (await prisma.follow.findUnique({
          where: { followerId_followingId: { followerId: viewerId, followingId: targetId } },
        })) !== null;

  const { _count, ...rest } = user;
  return {
    ...rest,
    followerCount: _count.followers,
    followingCount: _count.following,
    gameEntryCount: _count.gameEntries,
    isFollowedByMe,
  };
}

export async function follow(followerId: string, followingId: string) {
  if (followerId === followingId) {
    throw new AppError(400, 'invalid_operation', 'Não é possível seguir a si mesmo');
  }

  const target = await prisma.user.findUnique({ where: { id: followingId } });
  if (!target) throw new AppError(404, 'not_found', 'Usuário não encontrado');

  await prisma.follow.upsert({
    where: { followerId_followingId: { followerId, followingId } },
    update: {},
    create: { followerId, followingId },
  });

  await notificationsService.notify({ userId: followingId, actorId: followerId, type: 'follow' });
}

export async function unfollow(followerId: string, followingId: string) {
  await prisma.follow.deleteMany({ where: { followerId, followingId } });
}

export async function setPushToken(userId: string, token: string) {
  await prisma.user.update({ where: { id: userId }, data: { expoPushToken: token } });
}
