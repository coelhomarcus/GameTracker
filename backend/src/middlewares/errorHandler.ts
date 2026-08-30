import type { NextFunction, Request, Response } from 'express';
import { MulterError } from 'multer';
import { AppError } from '../lib/errors';

export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction) {
  if (err instanceof AppError) {
    res.status(err.statusCode).json({ error: { code: err.code, message: err.message } });
    return;
  }

  // erro de upload (arquivo grande demais, tipo inválido no fileFilter, etc)
  if (err instanceof MulterError || (err instanceof Error && err.message === 'Arquivo precisa ser uma imagem')) {
    res.status(400).json({ error: { code: 'validation_error', message: err.message } });
    return;
  }

  console.error(err);
  res.status(500).json({ error: { code: 'internal_error', message: 'Erro interno' } });
}
