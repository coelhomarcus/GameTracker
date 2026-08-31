import { z } from 'zod';

export const usernameSchema = z
  .string()
  .min(3)
  .max(30)
  .regex(/^[a-zA-Z0-9_]+$/, 'Use apenas letras, números e underscore');

export const registerSchema = z.object({
  username: usernameSchema,
  name: z.string().min(1).max(50),
  email: z.string().email().max(255),
  password: z.string().min(8).max(72),
});

export const loginSchema = z.object({
  identifier: z.string().min(1),
  password: z.string().min(1),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});
