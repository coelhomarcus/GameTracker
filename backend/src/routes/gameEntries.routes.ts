import { Router } from 'express';
import {
  createHandler,
  listMineHandler,
  removeHandler,
  updateHandler,
} from '../controllers/gameEntries.controller';
import { requireAuth } from '../middlewares/auth';
import { validateBody, validateQuery } from '../middlewares/validate';
import {
  createGameEntrySchema,
  listGameEntriesQuerySchema,
  updateGameEntrySchema,
} from '../schemas/gameEntry.schema';

export const gameEntriesRouter = Router();

gameEntriesRouter.use(requireAuth);

gameEntriesRouter.post('/', validateBody(createGameEntrySchema), createHandler);
gameEntriesRouter.get('/me', validateQuery(listGameEntriesQuerySchema), listMineHandler);
gameEntriesRouter.patch('/:id', validateBody(updateGameEntrySchema), updateHandler);
gameEntriesRouter.delete('/:id', removeHandler);
