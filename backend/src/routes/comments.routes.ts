import { Router } from 'express';
import { likeCommentHandler, unlikeCommentHandler } from '../controllers/comments.controller';
import { requireAuth } from '../middlewares/auth';

export const commentsRouter = Router();

commentsRouter.use(requireAuth);

commentsRouter.post('/:id/like', likeCommentHandler);
commentsRouter.delete('/:id/like', unlikeCommentHandler);
