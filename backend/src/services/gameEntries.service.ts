import { and, desc, eq, inArray } from 'drizzle-orm';
import { db } from '../db';
import { gameEntries, gameEntryStatusEnum, games } from '../db/schema';
import { AppError } from '../lib/errors';
import { findOrCacheGameByIgdbId } from './games.service';
import * as postsService from './posts.service';

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

const ACTIVITY_VERB: Partial<Record<GameEntryStatus, (gameName: string) => string>> = {
  backlog: (name) => `adicionou ${name} ao backlog`,
  playing: (name) => `começou a jogar ${name}`,
  completed: (name) => `zerou ${name}! 🎉`,
};

/** Best-effort: nunca deixa o post automático quebrar o fluxo principal de criar/atualizar o registro. */
async function createActivityPost(userId: string, entryId: string, gameName: string, status: GameEntryStatus) {
  const content = ACTIVITY_VERB[status]?.(gameName);
  if (!content) return;

  try {
    await postsService.create(userId, { content, gameEntryId: entryId, type: 'activity' });
  } catch (err) {
    console.error('Falha ao criar post de atividade automático:', err);
  }
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

  void createActivityPost(userId, created!.id, game.name, input.status);

  return getWithGame(created!.id);
}

export async function listMine(userId: string, filters: { status?: GameEntryStatus; igdbId?: number } = {}) {
  const conditions = [eq(gameEntries.userId, userId)];
  if (filters.status) conditions.push(eq(gameEntries.status, filters.status));
  if (filters.igdbId) {
    conditions.push(
      inArray(
        gameEntries.gameId,
        db.select({ id: games.id }).from(games).where(eq(games.igdbId, filters.igdbId)),
      ),
    );
  }

  return db.query.gameEntries.findMany({
    where: and(...conditions),
    with: { game: true },
    orderBy: desc(gameEntries.createdAt),
  });
}

export async function update(userId: string, entryId: string, input: UpdateInput) {
  const existing = await getOwnedEntry(userId, entryId);

  await db
    .update(gameEntries)
    .set({ ...input, hoursPlayed: input.hoursPlayed?.toString() })
    .where(eq(gameEntries.id, entryId));

  const result = await getWithGame(entryId);

  if (input.status && input.status !== existing.status && result && (input.status === 'playing' || input.status === 'completed')) {
    void createActivityPost(userId, entryId, result.game.name, input.status);
  }

  return result;
}

export async function remove(userId: string, entryId: string) {
  await getOwnedEntry(userId, entryId);
  await db.delete(gameEntries).where(eq(gameEntries.id, entryId));
}
