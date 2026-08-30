import type { Request, Response } from 'express';
import * as notificationsService from '../services/notifications.service';

export async function listHandler(req: Request, res: Response) {
  const result = await notificationsService.list(req.user!.id);
  res.json(result);
}

export async function markAllReadHandler(req: Request, res: Response) {
  await notificationsService.markAllRead(req.user!.id);
  res.status(204).send();
}
