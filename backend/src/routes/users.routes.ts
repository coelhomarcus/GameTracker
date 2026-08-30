import { Router } from 'express';
import {
  followHandler,
  getPublicProfileHandler,
  getUserPostsHandler,
  searchHandler,
  setPushTokenHandler,
  unfollowHandler,
  updateProfileHandler,
  uploadAvatarHandler,
} from '../controllers/users.controller';
import { requireAuth } from '../middlewares/auth';
import { validateBody, validateQuery } from '../middlewares/validate';
import { avatarUpload } from '../lib/uploads';
import {
  pushTokenSchema,
  searchUsersQuerySchema,
  updateProfileSchema,
  userPostsQuerySchema,
} from '../schemas/users.schema';

export const usersRouter = Router();

usersRouter.use(requireAuth);

usersRouter.patch('/me', validateBody(updateProfileSchema), updateProfileHandler);
usersRouter.post('/me/push-token', validateBody(pushTokenSchema), setPushTokenHandler);
usersRouter.post('/me/avatar', avatarUpload.single('avatar'), uploadAvatarHandler);
usersRouter.get('/search', validateQuery(searchUsersQuerySchema), searchHandler);
usersRouter.get('/:id', getPublicProfileHandler);
usersRouter.get('/:id/posts', validateQuery(userPostsQuerySchema), getUserPostsHandler);
usersRouter.post('/:id/follow', followHandler);
usersRouter.delete('/:id/follow', unfollowHandler);
