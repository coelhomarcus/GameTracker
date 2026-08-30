import { AppError } from '../lib/errors';
import { prisma } from '../lib/prisma';
import * as notificationsService from './notifications.service';

const userSelect = { id: true, username: true, avatarUrl: true } as const;

const postInclude = (viewerId: string) => ({
  user: { select: userSelect },
  gameEntry: { include: { game: true } },
  _count: { select: { likes: true, comments: true } },
  likes: { where: { userId: viewerId }, select: { id: true } },
});

function mapPost<T extends { likes: { id: string }[]; _count: { likes: number; comments: number } }>(post: T) {
  const { likes, _count, ...rest } = post;
  return { ...rest, likeCount: _count.likes, commentCount: _count.comments, likedByMe: likes.length > 0 };
}

interface CreatePostInput {
  content: string;
  gameEntryId?: string;
  type: 'status' | 'review' | 'activity';
  imageUrl?: string;
}

export async function create(userId: string, input: CreatePostInput) {
  if (input.gameEntryId) {
    const entry = await prisma.gameEntry.findUnique({ where: { id: input.gameEntryId } });
    if (!entry || entry.userId !== userId) {
      throw new AppError(404, 'not_found', 'Registro de jogo não encontrado');
    }
  }

  const post = await prisma.post.create({
    data: { userId, content: input.content, gameEntryId: input.gameEntryId, type: input.type, imageUrl: input.imageUrl },
    include: postInclude(userId),
  });

  return mapPost(post);
}

export async function getFeed(userId: string, cursor: string | undefined, limit: number) {
  const following = await prisma.follow.findMany({ where: { followerId: userId }, select: { followingId: true } });
  const authorIds = [userId, ...following.map((f) => f.followingId)];

  const posts = await prisma.post.findMany({
    where: { userId: { in: authorIds } },
    orderBy: { createdAt: 'desc' },
    take: limit + 1,
    ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    include: postInclude(userId),
  });

  const hasMore = posts.length > limit;
  const items = posts.slice(0, limit).map(mapPost);
  const nextCursor = hasMore ? items[items.length - 1]?.id : null;

  return { items, nextCursor };
}

async function getPostOrThrow(postId: string) {
  const post = await prisma.post.findUnique({ where: { id: postId } });
  if (!post) throw new AppError(404, 'not_found', 'Post não encontrado');
  return post;
}

export async function like(userId: string, postId: string) {
  const post = await getPostOrThrow(postId);

  await prisma.like.upsert({
    where: { postId_userId: { postId, userId } },
    update: {},
    create: { postId, userId },
  });

  await notificationsService.notify({ userId: post.userId, actorId: userId, type: 'like', postId });
}

export async function unlike(userId: string, postId: string) {
  await getPostOrThrow(postId);
  await prisma.like.deleteMany({ where: { postId, userId } });
}

export async function addComment(userId: string, postId: string, content: string) {
  const post = await getPostOrThrow(postId);

  const comment = await prisma.comment.create({
    data: { postId, userId, content },
    include: { user: { select: userSelect } },
  });

  await notificationsService.notify({ userId: post.userId, actorId: userId, type: 'comment', postId });

  return comment;
}

export async function listComments(postId: string) {
  await getPostOrThrow(postId);
  return prisma.comment.findMany({
    where: { postId },
    orderBy: { createdAt: 'asc' },
    include: { user: { select: userSelect } },
  });
}
