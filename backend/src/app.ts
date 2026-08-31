import cors from 'cors';
import express from 'express';
import path from 'node:path';
import { errorHandler } from './middlewares/errorHandler';
import { authRouter } from './routes/auth.routes';
import { conversationsRouter } from './routes/conversations.routes';
import { feedRouter } from './routes/feed.routes';
import { gameEntriesRouter } from './routes/gameEntries.routes';
import { gamesRouter } from './routes/games.routes';
import { imagesRouter } from './routes/images.routes';
import { notificationsRouter } from './routes/notifications.routes';
import { postsRouter } from './routes/posts.routes';
import { usersRouter } from './routes/users.routes';

export const app = express();

app.set('trust proxy', 1);

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/api/auth', authRouter);
app.use('/api/games', gamesRouter);
app.use('/api/images', imagesRouter);
app.use('/api/game-entries', gameEntriesRouter);
app.use('/api/posts', postsRouter);
app.use('/api/feed', feedRouter);
app.use('/api/users', usersRouter);
app.use('/api/notifications', notificationsRouter);
app.use('/api/conversations', conversationsRouter);

app.use(errorHandler);
