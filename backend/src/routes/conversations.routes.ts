import { Router } from 'express';
import {
  createHandler,
  listHandler,
  markReadHandler,
  messagesHandler,
} from '../controllers/conversations.controller';
import { requireAuth } from '../middlewares/auth';
import { validateBody, validateQuery } from '../middlewares/validate';
import { createConversationSchema, messagesQuerySchema } from '../schemas/conversations.schema';

export const conversationsRouter = Router();

conversationsRouter.use(requireAuth);

conversationsRouter.get('/', listHandler);
conversationsRouter.post('/', validateBody(createConversationSchema), createHandler);
conversationsRouter.get('/:id/messages', validateQuery(messagesQuerySchema), messagesHandler);
conversationsRouter.post('/:id/read', markReadHandler);
