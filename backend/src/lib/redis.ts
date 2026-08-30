import 'dotenv/config';
import Redis from 'ioredis';

const REDIS_URL = process.env.REDIS_URL ?? 'redis://localhost:6379';

export function createRedisClient() {
  return new Redis(REDIS_URL);
}
