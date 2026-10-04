import type { NextFunction, Request, Response } from 'express';
import { Router } from 'express';
import { registerHandler, revokeHandler } from '../controllers/push.controller';
import { AppError } from '../lib/errors';
import { requireAuth } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { installationParamsSchema, registerInstallationSchema } from '../schemas/push.schema';

export const pushRouter = Router();

pushRouter.use(requireAuth);

function validateInstallationId(req: Request, _res: Response, next: NextFunction) {
  const result = installationParamsSchema.safeParse(req.params);
  if (!result.success) {
    throw new AppError(400, 'validation_error', result.error.issues[0]?.message ?? 'Parâmetro inválido');
  }
  next();
}

pushRouter.put('/installations/:installationId', validateInstallationId, validateBody(registerInstallationSchema), registerHandler);
pushRouter.delete('/installations/:installationId', validateInstallationId, revokeHandler);
