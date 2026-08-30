import { Router } from 'express';
import { getByIdHandler, getByIgdbIdHandler, searchHandler } from '../controllers/games.controller';
import { requireAuth } from '../middlewares/auth';
import { validateQuery } from '../middlewares/validate';
import { searchGamesQuerySchema } from '../schemas/games.schema';

export const gamesRouter = Router();

gamesRouter.use(requireAuth);

gamesRouter.get('/search', validateQuery(searchGamesQuerySchema), searchHandler);
gamesRouter.get('/igdb/:igdbId', getByIgdbIdHandler);
gamesRouter.get('/:id', getByIdHandler);
