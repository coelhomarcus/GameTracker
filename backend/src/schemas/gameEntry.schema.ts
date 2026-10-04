import { z } from 'zod';

const statusEnum = z.enum(['backlog', 'playing', 'completed', 'dropped']);

export const createGameEntrySchema = z.object({
  igdbId: z.coerce.number().int().positive(),
  platform: z.string().min(1).max(50),
  status: statusEnum.optional().default('backlog'),
  startedAt: z.coerce.date().optional(),
  finishedAt: z.coerce.date().optional(),
  // Teto do numeric(6,1) da coluna (5 dígitos + 1 casa decimal) — o app já
  // valida um teto mais realista com base em início/fim, este é só a última
  // linha de defesa contra o overflow cru do Postgres.
  hoursPlayed: z.number().nonnegative().max(99999, 'Horas jogadas parecem irreais demais').optional(),
  rating: z.number().int().min(1).max(10).optional(),
  notes: z.string().max(2000).optional(),
});

/**
 * PATCH com três estados por campo opcional: omitido = manter, `null` = limpar,
 * valor = substituir. `.nullable()` vem antes da coerção da data de propósito:
 * sem isso `z.coerce.date()` transformaria `null` em 1970-01-01.
 * `platform` e `status` são obrigatórios no registro e não aceitam `null`.
 */
export const updateGameEntrySchema = z.object({
  platform: z.string().min(1).max(50).optional(),
  status: statusEnum.optional(),
  startedAt: z.coerce.date().nullable().optional(),
  finishedAt: z.coerce.date().nullable().optional(),
  // Teto do numeric(6,1) da coluna (5 dígitos + 1 casa decimal) — o app já
  // valida um teto mais realista com base em início/fim, este é só a última
  // linha de defesa contra o overflow cru do Postgres.
  hoursPlayed: z.number().nonnegative().max(99999, 'Horas jogadas parecem irreais demais').nullable().optional(),
  rating: z.number().int().min(1).max(10).nullable().optional(),
  notes: z.string().max(2000).nullable().optional(),
});

export const listGameEntriesQuerySchema = z.object({
  status: statusEnum.optional(),
  igdbId: z.coerce.number().int().positive().optional(),
  // Só usado por GET /game-entries/me; o mesmo schema serve GET
  // /users/:id/game-entries, que ignora o campo.
  sort: z.enum(['recent', 'oldest', 'most_played']).optional().default('recent'),
});
