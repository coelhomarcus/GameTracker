import { z } from 'zod';

export const createPostSchema = z.object({
  content: z.string().min(1).max(500),
  gameEntryId: z.string().uuid().optional(),
  type: z.enum(['status', 'review', 'activity']).optional().default('status'),
  imageUrl: z.string().url().max(500).optional(),
});

export const feedQuerySchema = z.object({
  cursor: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(50).optional().default(20),
});

export const createCommentSchema = z.object({
  content: z.string().min(1).max(500),
});
