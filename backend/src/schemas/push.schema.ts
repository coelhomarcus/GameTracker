import { z } from 'zod';

export const registerInstallationSchema = z.object({
  provider: z.enum(['expo', 'fcm']),
  platform: z.enum(['android', 'ios', 'web']),
  // Tokens FCM passam de 255 caracteres.
  token: z.string().min(1).max(4096),
});

export const installationParamsSchema = z.object({
  installationId: z.string().uuid('installationId precisa ser um UUID'),
});
