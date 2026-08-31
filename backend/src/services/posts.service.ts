import { and, asc, desc, eq, inArray, ne, sql, type SQL } from 'drizzle-orm';
import { db } from '../db';
import { commentLikes, comments, follows, gameEntries, likes, postTypeEnum, posts } from '../db/schema';
import { AppError } from '../lib/errors';
import { decodeCursor, encodeCursor } from '../lib/cursor';
import * as notificationsService from './notifications.service';

type PostType = (typeof postTypeEnum.enumValues)[number];

const userColumns = { id: true, username: true, name: true, avatarUrl: true } as const;

const postWith = {
  user: { columns: userColumns },
  gameEntry: { with: { game: true } },
  likes: { columns: { userId: true } },
  comments: { columns: { id: true } },
} as const;

function mapPost<T extends { likes: { userId: string }[]; comments: { id: string }[] }>(post: T, viewerId: string) {
  const { likes: postLikes, comments: postComments, ...rest } = post;
  return {
    ...rest,
    likeCount: postLikes.length,
    commentCount: postComments.length,
    likedByMe: postLikes.some((l) => l.userId === viewerId),
  };
}

async function getPostById(id: string, viewerId: string) {
  const post = await db.query.posts.findFirst({ where: eq(posts.id, id), with: postWith });
  if (!post) return undefined;
  return mapPost(post, viewerId);
}

export async function getById(id: string, viewerId: string) {
  const post = await getPostById(id, viewerId);
  if (!post) throw new AppError(404, 'not_found', 'Post não encontrado');
  return post;
}

interface CreatePostInput {
  content: string;
  gameEntryId?: string;
  type: PostType;
  imageUrl?: string;
}

export async function create(userId: string, input: CreatePostInput) {
  if (input.gameEntryId) {
    const entry = await db.query.gameEntries.findFirst({ where: eq(gameEntries.id, input.gameEntryId) });
    if (!entry || entry.userId !== userId) {
      throw new AppError(404, 'not_found', 'Registro de jogo não encontrado');
    }
  }

  const [created] = await db
    .insert(posts)
    .values({
      userId,
      content: input.content,
      gameEntryId: input.gameEntryId,
      type: input.type,
      imageUrl: input.imageUrl,
    })
    .returning();

  return getPostById(created!.id, userId);
}

async function paginatedPosts(viewerId: string, whereFilter: SQL | undefined, cursor: string | undefined, limit: number) {
  const cursorFilter = cursor
    ? (() => {
        const decoded = decodeCursor(cursor);
        return sql`(${posts.createdAt}, ${posts.id}) < (${decoded.createdAt.toISOString()}, ${decoded.id})`;
      })()
    : undefined;

  const results = await db.query.posts.findMany({
    where: whereFilter && cursorFilter ? and(whereFilter, cursorFilter) : (whereFilter ?? cursorFilter),
    orderBy: [desc(posts.createdAt), desc(posts.id)],
    limit: limit + 1,
    with: postWith,
  });

  const hasMore = results.length > limit;
  const page = results.slice(0, limit);
  const items = page.map((p) => mapPost(p, viewerId));
  const last = page[page.length - 1];
  const nextCursor = hasMore && last ? encodeCursor(last.createdAt, last.id) : null;

  return { items, nextCursor };
}

export async function getFeed(
  userId: string,
  cursor: string | undefined,
  limit: number,
  scope: 'following' | 'general' = 'following',
) {
  let scopeFilter: SQL | undefined;
  if (scope === 'following') {
    const following = await db.select({ followingId: follows.followingId }).from(follows).where(eq(follows.followerId, userId));
    const authorIds = [userId, ...following.map((f) => f.followingId)];
    scopeFilter = inArray(posts.userId, authorIds);
  }

  return paginatedPosts(userId, scopeFilter, cursor, limit);
}

export async function getUserPosts(
  viewerId: string,
  targetUserId: string,
  cursor: string | undefined,
  limit: number,
  type?: 'activity' | 'post',
) {
  const typeFilter = type === 'activity' ? eq(posts.type, 'activity') : type === 'post' ? ne(posts.type, 'activity') : undefined;
  const whereFilter = typeFilter ? and(eq(posts.userId, targetUserId), typeFilter) : eq(posts.userId, targetUserId);
  return paginatedPosts(viewerId, whereFilter, cursor, limit);
}

export async function getUserComments(targetUserId: string, cursor: string | undefined, limit: number) {
  const cursorFilter = cursor
    ? (() => {
        const decoded = decodeCursor(cursor);
        return sql`(${comments.createdAt}, ${comments.id}) < (${decoded.createdAt.toISOString()}, ${decoded.id})`;
      })()
    : undefined;

  const whereFilter = eq(comments.userId, targetUserId);

  const results = await db.query.comments.findMany({
    where: cursorFilter ? and(whereFilter, cursorFilter) : whereFilter,
    orderBy: [desc(comments.createdAt), desc(comments.id)],
    limit: limit + 1,
    with: { post: { with: { user: { columns: userColumns } } } },
  });

  const hasMore = results.length > limit;
  const items = results.slice(0, limit);
  const last = items[items.length - 1];
  const nextCursor = hasMore && last ? encodeCursor(last.createdAt, last.id) : null;

  return { items, nextCursor };
}

async function getPostOrThrow(postId: string) {
  const post = await db.query.posts.findFirst({ where: eq(posts.id, postId) });
  if (!post) throw new AppError(404, 'not_found', 'Post não encontrado');
  return post;
}

export async function like(userId: string, postId: string) {
  const post = await getPostOrThrow(postId);

  await db.insert(likes).values({ postId, userId }).onConflictDoNothing({ target: [likes.postId, likes.userId] });

  await notificationsService.notify({ userId: post.userId, actorId: userId, type: 'like', postId });
}

export async function unlike(userId: string, postId: string) {
  await getPostOrThrow(postId);
  await db.delete(likes).where(and(eq(likes.postId, postId), eq(likes.userId, userId)));
}

async function getCommentOrThrow(commentId: string) {
  const comment = await db.query.comments.findFirst({ where: eq(comments.id, commentId) });
  if (!comment) throw new AppError(404, 'not_found', 'Comentário não encontrado');
  return comment;
}

export async function addComment(userId: string, postId: string, content: string, parentCommentId?: string) {
  const post = await getPostOrThrow(postId);

  let notifyUserId = post.userId;
  if (parentCommentId) {
    const parent = await getCommentOrThrow(parentCommentId);
    if (parent.postId !== postId) throw new AppError(400, 'invalid_operation', 'Comentário pai não pertence a esse post');
    notifyUserId = parent.userId;
  }

  const [created] = await db.insert(comments).values({ postId, userId, content, parentCommentId }).returning();
  const comment = await db.query.comments.findFirst({
    where: eq(comments.id, created!.id),
    with: { user: { columns: userColumns } },
  });

  await notificationsService.notify({ userId: notifyUserId, actorId: userId, type: 'comment', postId });

  return comment;
}

interface FlatComment {
  id: string;
  parentCommentId: string | null;
  createdAt: Date;
  likes: { userId: string }[];
  [key: string]: unknown;
}

function buildCommentTree(flat: FlatComment[], viewerId: string) {
  const mapped = flat.map((c) => {
    const { likes: commentLikeRows, parentCommentId, ...rest } = c;
    return {
      ...rest,
      parentCommentId,
      likeCount: commentLikeRows.length,
      likedByMe: commentLikeRows.some((l) => l.userId === viewerId),
      replies: [] as unknown[],
    };
  });

  const byId = new Map(mapped.map((c) => [c.id, c]));
  const roots: (typeof mapped)[number][] = [];

  for (const c of mapped) {
    if (c.parentCommentId) {
      const parent = byId.get(c.parentCommentId);
      if (parent) {
        parent.replies.push(c);
        continue;
      }
    }
    roots.push(c);
  }

  return roots;
}

export async function listComments(postId: string, viewerId: string) {
  await getPostOrThrow(postId);
  const flat = await db.query.comments.findMany({
    where: eq(comments.postId, postId),
    orderBy: asc(comments.createdAt),
    with: { user: { columns: userColumns }, likes: { columns: { userId: true } } },
  });
  return buildCommentTree(flat, viewerId);
}

export async function likeComment(userId: string, commentId: string) {
  await getCommentOrThrow(commentId);

  await db
    .insert(commentLikes)
    .values({ commentId, userId })
    .onConflictDoNothing({ target: [commentLikes.commentId, commentLikes.userId] });
}

export async function unlikeComment(userId: string, commentId: string) {
  await getCommentOrThrow(commentId);
  await db.delete(commentLikes).where(and(eq(commentLikes.commentId, commentId), eq(commentLikes.userId, userId)));
}
