import { Router } from 'express';
import {
  followHandler,
  getPublicProfileHandler,
  setPushTokenHandler,
  unfollowHandler,
} from '../controllers/users.controller';
import { requireAuth } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { pushTokenSchema } from '../schemas/users.schema';

export const usersRouter = Router();

usersRouter.use(requireAuth);

usersRouter.post('/me/push-token', validateBody(pushTokenSchema), setPushTokenHandler);
usersRouter.get('/:id', getPublicProfileHandler);
usersRouter.post('/:id/follow', followHandler);
usersRouter.delete('/:id/follow', unfollowHandler);
