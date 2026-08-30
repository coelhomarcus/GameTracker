import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET ?? '';
const ACCESS_EXPIRES_IN = process.env.JWT_ACCESS_EXPIRES_IN ?? '15m';

export interface AccessTokenPayload {
  sub: string;
}

export function signAccessToken(userId: string): string {
  const expiresIn = ACCESS_EXPIRES_IN as NonNullable<jwt.SignOptions['expiresIn']>;
  return jwt.sign({ sub: userId }, ACCESS_SECRET, { expiresIn });
}

export function verifyAccessToken(token: string): AccessTokenPayload {
  return jwt.verify(token, ACCESS_SECRET) as AccessTokenPayload;
}

// Refresh tokens são opacos (não JWT): "<id>.<secret>". Só o hash do secret fica no banco,
// então um vazamento do banco não permite reconstruir tokens válidos.
export function generateRefreshTokenSecret(): { secret: string; hash: string } {
  const secret = crypto.randomBytes(32).toString('hex');
  return { secret, hash: hashRefreshTokenSecret(secret) };
}

export function hashRefreshTokenSecret(secret: string): string {
  return crypto.createHash('sha256').update(secret).digest('hex');
}

export function parseRefreshToken(raw: string): { id: string; secret: string } | null {
  const [id, secret] = raw.split('.');
  if (!id || !secret) return null;
  return { id, secret };
}
