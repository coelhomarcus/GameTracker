import bcrypt from 'bcrypt';
import { parseDurationMs } from '../lib/duration';
import { AppError } from '../lib/errors';
import { prisma } from '../lib/prisma';
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

function toPublicUser(user: { id: string; username: string; email: string; avatarUrl: string | null; bio: string | null }) {
  return { id: user.id, username: user.username, email: user.email, avatarUrl: user.avatarUrl, bio: user.bio };
}

async function issueSession(userId: string): Promise<Session> {
  const accessToken = signAccessToken(userId);
  const { secret, hash } = generateRefreshTokenSecret();
  const expiresAt = new Date(Date.now() + parseDurationMs(REFRESH_EXPIRES_IN));

  const record = await prisma.refreshToken.create({
    data: { userId, tokenHash: hash, expiresAt },
  });

  return { accessToken, refreshToken: `${record.id}.${secret}` };
}

export async function register(username: string, email: string, password: string) {
  const existing = await prisma.user.findFirst({ where: { OR: [{ username }, { email }] } });
  if (existing) {
    throw new AppError(409, 'conflict', 'Username ou email já cadastrado');
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const user = await prisma.user.create({ data: { username, email, passwordHash } });
  const session = await issueSession(user.id);

  return { user: toPublicUser(user), ...session };
}

export async function login(email: string, password: string) {
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) {
    throw new AppError(401, 'invalid_credentials', 'Email ou senha inválidos');
  }

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) {
    throw new AppError(401, 'invalid_credentials', 'Email ou senha inválidos');
  }

  const session = await issueSession(user.id);
  return { user: toPublicUser(user), ...session };
}

export async function refresh(rawRefreshToken: string) {
  const parsed = parseRefreshToken(rawRefreshToken);
  if (!parsed) {
    throw new AppError(401, 'invalid_refresh_token', 'Refresh token inválido');
  }

  const record = await prisma.refreshToken.findUnique({ where: { id: parsed.id } });
  const providedHash = hashRefreshTokenSecret(parsed.secret);

  if (!record || record.revokedAt || record.expiresAt < new Date() || record.tokenHash !== providedHash) {
    throw new AppError(401, 'invalid_refresh_token', 'Refresh token inválido ou expirado');
  }

  await prisma.refreshToken.update({ where: { id: record.id }, data: { revokedAt: new Date() } });

  return issueSession(record.userId);
}

export async function me(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) {
    throw new AppError(404, 'not_found', 'Usuário não encontrado');
  }
  return toPublicUser(user);
}

export async function logout(rawRefreshToken: string) {
  const parsed = parseRefreshToken(rawRefreshToken);
  if (!parsed) return;

  await prisma.refreshToken.updateMany({
    where: { id: parsed.id, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}
