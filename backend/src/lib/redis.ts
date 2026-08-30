import 'dotenv/config';
import Redis from 'ioredis';

const REDIS_URL = process.env.REDIS_URL ?? 'redis://localhost:6379';

export function createRedisClient(label = 'redis') {
  const client = new Redis(REDIS_URL);
  // Sem esse handler, o ioredis só loga "missing 'error' handler" em loop
  // a cada tentativa de reconexão, escondendo o erro real por trás.
  client.on('error', (err: NodeJS.ErrnoException) => {
    console.error(`[${label}] erro de conexão: ${err.code ?? err.message}`);
  });
  return client;
}
