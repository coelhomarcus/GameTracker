import { z } from 'zod';

export const pushTokenSchema = z.object({
  token: z.string().min(1).max(255),
});

export const searchUsersQuerySchema = z.object({
  q: z.string().min(1).max(50),
});

export const updateProfileSchema = z.object({
  bio: z.string().max(280).optional(),
});

export const userPostsQuerySchema = z.object({
  cursor: z.string().min(1).optional(),
  limit: z.coerce.number().int().min(1).max(50).optional().default(20),
  type: z.enum(['activity', 'post']).optional(),
});
