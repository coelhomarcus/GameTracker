import bcrypt from 'bcrypt';
import { and, eq, isNull, or } from 'drizzle-orm';
import { db } from '../db';
import { refreshTokens, users } from '../db/schema';
import { parseDurationMs } from '../lib/duration';
import { AppError } from '../lib/errors';
import {
  generateRefreshTokenSecret,
  hashRefreshTokenSecret,
  parseRefreshToken,
  signAccessToken,
} from '../lib/tokens';

const REFRESH_EXPIRES_IN = process.env.JWT_REFRESH_EXPIRES_IN ?? '30d';

interface Session {
  accessToken: string;
  refreshToken: string;
}

function toPublicUser(user: {
  id: string;
  username: string;
  name: string | null;
  email: string;
  avatarUrl: string | null;
  bannerUrl: string | null;
  bio: string | null;
}) {
  return {
    id: user.id,
    username: user.username,
    name: user.name,
    email: user.email,
    avatarUrl: user.avatarUrl,
    bannerUrl: user.bannerUrl,
    bio: user.bio,
  };
}

async function issueSession(userId: string): Promise<Session> {
  const accessToken = signAccessToken(userId);
  const { secret, hash } = generateRefreshTokenSecret();
  const expiresAt = new Date(Date.now() + parseDurationMs(REFRESH_EXPIRES_IN));

  const [record] = await db.insert(refreshTokens).values({ userId, tokenHash: hash, expiresAt }).returning();

  return { accessToken, refreshToken: `${record!.id}.${secret}` };
}

export async function register(username: string, name: string, email: string, password: string) {
  const existing = await db.query.users.findFirst({ where: or(eq(users.username, username), eq(users.email, email)) });
  if (existing) {
    throw new AppError(409, 'conflict', 'Username ou email já cadastrado');
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const [user] = await db.insert(users).values({ username, name, email, passwordHash }).returning();
  const session = await issueSession(user!.id);

  return { user: toPublicUser(user!), ...session };
}

export async function login(identifier: string, password: string) {
  const user = await db.query.users.findFirst({
    where: or(eq(users.email, identifier), eq(users.username, identifier)),
  });
  if (!user) {
    throw new AppError(401, 'invalid_credentials', 'Credenciais inválidas');
  }

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) {
    throw new AppError(401, 'invalid_credentials', 'Credenciais inválidas');
  }

  const session = await issueSession(user.id);
  return { user: toPublicUser(user), ...session };
}

export async function refresh(rawRefreshToken: string) {
  const parsed = parseRefreshToken(rawRefreshToken);
  if (!parsed) {
    throw new AppError(401, 'invalid_refresh_token', 'Refresh token inválido');
  }

  const record = await db.query.refreshTokens.findFirst({ where: eq(refreshTokens.id, parsed.id) });
  const providedHash = hashRefreshTokenSecret(parsed.secret);

  if (!record || record.revokedAt || record.expiresAt < new Date() || record.tokenHash !== providedHash) {
    throw new AppError(401, 'invalid_refresh_token', 'Refresh token inválido ou expirado');
  }

  await db.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.id, record.id));

  return issueSession(record.userId);
}

export async function me(userId: string) {
  const user = await db.query.users.findFirst({ where: eq(users.id, userId) });
  if (!user) {
    throw new AppError(404, 'not_found', 'Usuário não encontrado');
  }
  return toPublicUser(user);
}

export async function logout(rawRefreshToken: string) {
  const parsed = parseRefreshToken(rawRefreshToken);
  if (!parsed) return;

  await db
    .update(refreshTokens)
    .set({ revokedAt: new Date() })
    .where(and(eq(refreshTokens.id, parsed.id), isNull(refreshTokens.revokedAt)));
}
