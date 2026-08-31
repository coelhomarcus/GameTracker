import { and, asc, desc, eq, inArray } from 'drizzle-orm';
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
  dropped: (name) => `abandonou ${name}`,
};

/** Best-effort: nunca deixa o post automático quebrar o fluxo principal de criar/atualizar o registro. */
async function createActivityPost(userId: string, entryId: string, gameName: string, status: GameEntryStatus) {
  const content = ACTIVITY_VERB[status]?.(gameName);
  if (!content) return;

  try {
    // activityStatus é o snapshot imutável do status no momento desta
    // atividade — não pode vir de gameEntry.status, que muda depois.
    await postsService.create(userId, { content, gameEntryId: entryId, activityStatus: status, type: 'activity' });
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
  const game = await findOrCacheGameByIgdbId(input.igdbId, userId);

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

const SORT_ORDER = {
  recent: desc(gameEntries.createdAt),
  oldest: asc(gameEntries.createdAt),
  most_played: desc(gameEntries.hoursPlayed),
} as const;

export async function listMine(
  userId: string,
  filters: { status?: GameEntryStatus; igdbId?: number; sort?: keyof typeof SORT_ORDER } = {},
) {
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
    orderBy: SORT_ORDER[filters.sort ?? 'recent'],
  });
}

export async function update(userId: string, entryId: string, input: UpdateInput) {
  const existing = await getOwnedEntry(userId, entryId);

  await db
    .update(gameEntries)
    .set({ ...input, hoursPlayed: input.hoursPlayed?.toString() })
    .where(eq(gameEntries.id, entryId));

  const result = await getWithGame(entryId);

  if (
    input.status &&
    input.status !== existing.status &&
    result &&
    (input.status === 'playing' || input.status === 'completed' || input.status === 'dropped')
  ) {
    void createActivityPost(userId, entryId, result.game.name, input.status);
  }

  return result;
}

export async function remove(userId: string, entryId: string) {
  await getOwnedEntry(userId, entryId);
  await db.delete(gameEntries).where(eq(gameEntries.id, entryId));
}
