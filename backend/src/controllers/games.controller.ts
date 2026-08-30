import type { Request, Response } from 'express';
import { AppError } from '../lib/errors';
import * as gamesService from '../services/games.service';

export async function searchHandler(_req: Request, res: Response) {
  const { q } = res.locals.query as { q: string };
  const results = await gamesService.searchGames(q);
  res.json(results);
}

export async function getByIdHandler(req: Request, res: Response) {
  const game = await gamesService.getGame(req.params.id as string);
  res.json(game);
}

export async function getByIgdbIdHandler(req: Request, res: Response) {
  const igdbId = Number(req.params.igdbId);
  if (!Number.isInteger(igdbId) || igdbId <= 0) {
    throw new AppError(400, 'validation_error', 'igdbId inválido');
  }
  const game = await gamesService.findOrCacheGameByIgdbId(igdbId);
  res.json(game);
}
