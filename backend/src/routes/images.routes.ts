import { Router } from 'express';
import { coverProxyHandler } from '../controllers/images.controller';

export const imagesRouter = Router();

imagesRouter.get('/cover', coverProxyHandler);
