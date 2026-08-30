import { eq } from 'drizzle-orm';
import { db } from '../db';
import { games } from '../db/schema';
import { AppError } from '../lib/errors';
import * as igdb from '../lib/igdb';

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
      coverUrl: fromIgdb.coverUrl,
      platforms: fromIgdb.platforms,
      genres: fromIgdb.genres,
    })
    .returning();

  return created!;
}
