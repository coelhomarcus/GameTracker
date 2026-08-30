import { z } from 'zod';

export const createConversationSchema = z.object({
  userId: z.string().uuid(),
});

export const messagesQuerySchema = z.object({
  cursor: z.string().min(1).optional(),
  limit: z.coerce.number().int().min(1).max(100).optional().default(30),
});
