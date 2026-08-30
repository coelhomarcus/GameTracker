import { z } from 'zod';

export const searchGamesQuerySchema = z.object({
  q: z.string().min(1).max(100),
});
