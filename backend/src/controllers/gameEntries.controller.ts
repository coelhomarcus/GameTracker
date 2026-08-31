import type { Request, Response } from 'express';
import * as gameEntriesService from '../services/gameEntries.service';

export async function createHandler(req: Request, res: Response) {
  const entry = await gameEntriesService.create(req.user!.id, req.body);
  res.status(201).json(entry);
}

export async function listMineHandler(req: Request, res: Response) {
  const { status, igdbId, sort } = res.locals.query as {
    status?: 'backlog' | 'playing' | 'completed' | 'dropped';
    igdbId?: number;
    sort?: 'recent' | 'oldest' | 'most_played';
  };
  const entries = await gameEntriesService.listMine(req.user!.id, { status, igdbId, sort });
  res.json(entries);
}

export async function updateHandler(req: Request, res: Response) {
  const entry = await gameEntriesService.update(req.user!.id, req.params.id as string, req.body);
  res.json(entry);
}

export async function removeHandler(req: Request, res: Response) {
  await gameEntriesService.remove(req.user!.id, req.params.id as string);
  res.status(204).send();
}
