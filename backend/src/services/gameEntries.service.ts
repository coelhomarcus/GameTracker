import { and, desc, eq } from 'drizzle-orm';
import { db } from '../db';
import { gameEntries, gameEntryStatusEnum } from '../db/schema';
import { AppError } from '../lib/errors';
import { findOrCacheGameByIgdbId } from './games.service';

type GameEntryStatus = (typeof gameEntryStatusEnum.enumValues)[number];

interface CreateInput {
  igdbId: number;
  platform: string;
  status: GameEntryStatus;
  startedAt?: Date;
  finishedAt?: Date;
  hoursPlayed?: number;
  rating?: number;
  notes?: string;
}

type UpdateInput = Partial<Omit<CreateInput, 'igdbId'>>;

function getWithGame(id: string) {
  return db.query.gameEntries.findFirst({ where: eq(gameEntries.id, id), with: { game: true } });
}

async function getOwnedEntry(userId: string, entryId: string) {
  const entry = await db.query.gameEntries.findFirst({ where: eq(gameEntries.id, entryId) });
  if (!entry || entry.userId !== userId) {
    throw new AppError(404, 'not_found', 'Registro não encontrado');
  }
  return entry;
}

export async function create(userId: string, input: CreateInput) {
  const game = await findOrCacheGameByIgdbId(input.igdbId);

  const [created] = await db
    .insert(gameEntries)
    .values({
      userId,
      gameId: game.id,
      platform: input.platform,
      status: input.status,
      startedAt: input.startedAt,
      finishedAt: input.finishedAt,
      hoursPlayed: input.hoursPlayed?.toString(),
      rating: input.rating,
      notes: input.notes,
    })
    .returning();

  return getWithGame(created!.id);
}

export async function listMine(userId: string, status?: GameEntryStatus) {
  return db.query.gameEntries.findMany({
    where: status ? and(eq(gameEntries.userId, userId), eq(gameEntries.status, status)) : eq(gameEntries.userId, userId),
    with: { game: true },
    orderBy: desc(gameEntries.createdAt),
  });
}

export async function update(userId: string, entryId: string, input: UpdateInput) {
  await getOwnedEntry(userId, entryId);

  await db
    .update(gameEntries)
    .set({ ...input, hoursPlayed: input.hoursPlayed?.toString() })
    .where(eq(gameEntries.id, entryId));

  return getWithGame(entryId);
}

export async function remove(userId: string, entryId: string) {
  await getOwnedEntry(userId, entryId);
  await db.delete(gameEntries).where(eq(gameEntries.id, entryId));
}
