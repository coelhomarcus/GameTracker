import type { NextFunction, Request, Response } from 'express';
import type { ZodType } from 'zod';
import { AppError } from '../lib/errors';

export function validateBody(schema: ZodType) {
  return (req: Request, _res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      throw new AppError(400, 'validation_error', result.error.issues[0]?.message ?? 'Payload inválido');
    }
    req.body = result.data;
    next();
  };
}

// Express 5 torna `req.query` somente leitura, então o resultado validado fica em `res.locals.query`.
export function validateQuery(schema: ZodType) {
  return (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.query);
    if (!result.success) {
      throw new AppError(400, 'validation_error', result.error.issues[0]?.message ?? 'Query inválida');
    }
    res.locals.query = result.data;
    next();
  };
}
