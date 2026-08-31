import { Router } from 'express';
import {
  gamePostsHandler,
  getByIdHandler,
  getByIgdbIdHandler,
  playersHandler,
  searchHandler,
  statsHandler,
} from '../controllers/games.controller';
import { requireAuth } from '../middlewares/auth';
import { validateQuery } from '../middlewares/validate';
import { gamePlayersQuerySchema, gamePostsQuerySchema, searchGamesQuerySchema } from '../schemas/games.schema';

export const gamesRouter = Router();

gamesRouter.use(requireAuth);

gamesRouter.get('/search', validateQuery(searchGamesQuerySchema), searchHandler);
gamesRouter.get('/igdb/:igdbId', getByIgdbIdHandler);
gamesRouter.get('/:id', getByIdHandler);
gamesRouter.get('/:id/stats', statsHandler);
gamesRouter.get('/:id/players', validateQuery(gamePlayersQuerySchema), playersHandler);
gamesRouter.get('/:id/posts', validateQuery(gamePostsQuerySchema), gamePostsHandler);
