import type { Request, Response } from 'express';
import * as pushInstallationsService from '../services/pushInstallations.service';

export async function registerHandler(req: Request, res: Response) {
  await pushInstallationsService.register(req.user!.id, req.params.installationId as string, req.body);
  res.status(204).send();
}

export async function revokeHandler(req: Request, res: Response) {
  await pushInstallationsService.revoke(req.user!.id, req.params.installationId as string);
  res.status(204).send();
}
