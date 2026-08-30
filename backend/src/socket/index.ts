import type { Server as HttpServer } from 'node:http';
import { createAdapter } from '@socket.io/redis-adapter';
import { Server } from 'socket.io';
import { createRedisClient } from '../lib/redis';
import { verifyAccessToken } from '../lib/tokens';
import { registerChatHandlers } from './chatHandlers';

export function initSocket(httpServer: HttpServer) {
  const io = new Server(httpServer, { cors: { origin: '*' } });

  const pubClient = createRedisClient();
  const subClient = pubClient.duplicate();
  io.adapter(createAdapter(pubClient, subClient));

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token as string | undefined;
    if (!token) return next(new Error('unauthorized'));

    try {
      const payload = verifyAccessToken(token);
      socket.data.userId = payload.sub;
      next();
    } catch {
      next(new Error('unauthorized'));
    }
  });

  io.on('connection', (socket) => {
    registerChatHandlers(io, socket);
  });

  return io;
}
