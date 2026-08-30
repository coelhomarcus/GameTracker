import { Router } from 'express';
import {
  addCommentHandler,
  createHandler,
  likeHandler,
  listCommentsHandler,
  unlikeHandler,
} from '../controllers/posts.controller';
import { requireAuth } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { createCommentSchema, createPostSchema } from '../schemas/posts.schema';

export const postsRouter = Router();

postsRouter.use(requireAuth);

postsRouter.post('/', validateBody(createPostSchema), createHandler);
postsRouter.post('/:id/like', likeHandler);
postsRouter.delete('/:id/like', unlikeHandler);
postsRouter.post('/:id/comments', validateBody(createCommentSchema), addCommentHandler);
postsRouter.get('/:id/comments', listCommentsHandler);
