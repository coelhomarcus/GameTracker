import { Router } from 'express';
import { listHandler, markAllReadHandler } from '../controllers/notifications.controller';
import { requireAuth } from '../middlewares/auth';

export const notificationsRouter = Router();

notificationsRouter.use(requireAuth);

notificationsRouter.get('/', listHandler);
notificationsRouter.post('/read-all', markAllReadHandler);
