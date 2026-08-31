import { z } from 'zod';

const statusEnum = z.enum(['backlog', 'playing', 'completed', 'dropped']);

export const createGameEntrySchema = z.object({
  igdbId: z.coerce.number().int().positive(),
  platform: z.string().min(1).max(50),
  status: statusEnum.optional().default('backlog'),
  startedAt: z.coerce.date().optional(),
  finishedAt: z.coerce.date().optional(),
  hoursPlayed: z.number().nonnegative().optional(),
  rating: z.number().int().min(1).max(10).optional(),
  notes: z.string().max(2000).optional(),
});

export const updateGameEntrySchema = z.object({
  platform: z.string().min(1).max(50).optional(),
  status: statusEnum.optional(),
  startedAt: z.coerce.date().optional(),
  finishedAt: z.coerce.date().optional(),
  hoursPlayed: z.number().nonnegative().optional(),
  rating: z.number().int().min(1).max(10).optional(),
  notes: z.string().max(2000).optional(),
});

export const listGameEntriesQuerySchema = z.object({
  status: statusEnum.optional(),
  igdbId: z.coerce.number().int().positive().optional(),
  // Só usado por GET /game-entries/me; o mesmo schema serve GET
  // /users/:id/game-entries, que ignora o campo.
  sort: z.enum(['recent', 'oldest', 'most_played']).optional().default('recent'),
});
