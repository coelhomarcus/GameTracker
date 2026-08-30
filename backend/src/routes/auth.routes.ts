import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { loginHandler, logoutHandler, meHandler, refreshHandler, registerHandler } from '../controllers/auth.controller';
import { loginSchema, refreshSchema, registerSchema } from '../schemas/auth.schema';
import { requireAuth } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
});

export const authRouter = Router();

authRouter.post('/register', authLimiter, validateBody(registerSchema), registerHandler);
authRouter.post('/login', authLimiter, validateBody(loginSchema), loginHandler);
authRouter.post('/refresh', validateBody(refreshSchema), refreshHandler);
authRouter.post('/logout', validateBody(refreshSchema), logoutHandler);
authRouter.get('/me', requireAuth, meHandler);
