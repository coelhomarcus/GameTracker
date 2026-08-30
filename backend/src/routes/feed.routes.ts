import { Router } from 'express';
import { feedHandler } from '../controllers/posts.controller';
import { requireAuth } from '../middlewares/auth';
import { validateQuery } from '../middlewares/validate';
import { feedQuerySchema } from '../schemas/posts.schema';

export const feedRouter = Router();

feedRouter.get('/', requireAuth, validateQuery(feedQuerySchema), feedHandler);
