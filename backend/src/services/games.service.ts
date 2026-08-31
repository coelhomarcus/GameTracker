import { and, count, desc, eq, inArray } from 'drizzle-orm';
import { db } from '../db';
import { follows, gameEntries, gameEntryStatusEnum, games } from '../db/schema';
import { AppError } from '../lib/errors';
import * as igdb from '../lib/igdb';

type GameEntryStatus = (typeof gameEntryStatusEnum.enumValues)[number];

const userColumns = { id: true, username: true, name: true, avatarUrl: true } as const;

export async function searchGames(term: string) {
  return igdb.searchGames(term);
}

export async function getGame(id: string) {
  const game = await db.query.games.findFirst({ where: eq(games.id, id) });
  if (!game) throw new AppError(404, 'not_found', 'Jogo não encontrado');
  return game;
}

/** Busca o jogo no cache local; se ausente, consulta a IGDB e cacheia. */
export async function findOrCacheGameByIgdbId(igdbId: number) {
  const cached = await db.query.games.findFirst({ where: eq(games.igdbId, igdbId) });
  if (cached) return cached;

  const fromIgdb = await igdb.getGameByIgdbId(igdbId);
  if (!fromIgdb) throw new AppError(404, 'not_found', 'Jogo não encontrado na IGDB');

  const [created] = await db
    .insert(games)
    .values({
      igdbId: fromIgdb.igdbId,
      name: fromIgdb.name,
      summary: fromIgdb.summary,
      coverUrl: fromIgdb.coverUrl,
      screenshots: fromIgdb.screenshots,
      platforms: fromIgdb.platforms,
      genres: fromIgdb.genres,
    })
    .returning();

  return created!;
}

/** Contagem de playthroughs por status, pra "X jogando · Y zeraram · Z abandonaram". */
export async function getStats(gameId: string) {
  const rows = await db
    .select({ status: gameEntries.status, count: count() })
    .from(gameEntries)
    .where(eq(gameEntries.gameId, gameId))
    .groupBy(gameEntries.status);

  const stats: Record<GameEntryStatus, number> = { backlog: 0, playing: 0, completed: 0, dropped: 0 };
  for (const row of rows) stats[row.status] = row.count;
  return stats;
}

/**
 * "Quem está jogando" / "seus amigos estão jogando" — prévia limitada, sem
 * paginação. `scope: 'following'` reusa o mesmo padrão de `posts.service.ts`'s
 * `getFeed`: lista de `followingId` na tabela `follows`, filtrada com `inArray`.
 */
export async function getPlayers(
  gameId: string,
  viewerId: string,
  status: GameEntryStatus,
  scope: 'all' | 'following',
  limit: number,
) {
  const conditions = [eq(gameEntries.gameId, gameId), eq(gameEntries.status, status)];

  if (scope === 'following') {
    const following = await db
      .select({ followingId: follows.followingId })
      .from(follows)
      .where(eq(follows.followerId, viewerId));
    const authorIds = following.map((f) => f.followingId);
    if (authorIds.length === 0) return [];
    conditions.push(inArray(gameEntries.userId, authorIds));
  }

  const rows = await db.query.gameEntries.findMany({
    where: and(...conditions),
    orderBy: desc(gameEntries.createdAt),
    limit,
    with: { user: { columns: userColumns } },
  });

  return rows.map((row) => ({ user: row.user, status: row.status, hoursPlayed: row.hoursPlayed }));
}
