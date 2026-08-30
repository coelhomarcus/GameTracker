import type { Request, Response } from 'express';
import * as usersService from '../services/users.service';

export async function getPublicProfileHandler(req: Request, res: Response) {
  const profile = await usersService.getPublicProfile(req.user!.id, req.params.id as string);
  res.json(profile);
}

export async function followHandler(req: Request, res: Response) {
  await usersService.follow(req.user!.id, req.params.id as string);
  res.status(204).send();
}

export async function unfollowHandler(req: Request, res: Response) {
  await usersService.unfollow(req.user!.id, req.params.id as string);
  res.status(204).send();
}

export async function setPushTokenHandler(req: Request, res: Response) {
  await usersService.setPushToken(req.user!.id, req.body.token);
  res.status(204).send();
}
