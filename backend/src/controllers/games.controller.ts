import type { Request, Response } from 'express';
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
