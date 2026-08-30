import * as igdb from '../lib/igdb';
import { AppError } from '../lib/errors';
import { prisma } from '../lib/prisma';

export async function searchGames(term: string) {
  return igdb.searchGames(term);
}

export async function getGame(id: string) {
  const game = await prisma.game.findUnique({ where: { id } });
  if (!game) throw new AppError(404, 'not_found', 'Jogo não encontrado');
  return game;
}

/** Busca o jogo no cache local; se ausente, consulta a IGDB e cacheia. */
export async function findOrCacheGameByIgdbId(igdbId: number) {
  const cached = await prisma.game.findUnique({ where: { igdbId } });
  if (cached) return cached;

  const fromIgdb = await igdb.getGameByIgdbId(igdbId);
  if (!fromIgdb) throw new AppError(404, 'not_found', 'Jogo não encontrado na IGDB');

  return prisma.game.create({
    data: {
      igdbId: fromIgdb.igdbId,
      name: fromIgdb.name,
      coverUrl: fromIgdb.coverUrl,
      platforms: fromIgdb.platforms,
      genres: fromIgdb.genres,
    },
  });
}
