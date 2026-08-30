import type { Request, Response } from 'express';
import { AppError } from '../lib/errors';

const ALLOWED_HOST = 'images.igdb.com';

/**
 * Repassa imagens de capa da IGDB através da nossa API — a IGDB é bloqueada em algumas
 * redes (ex: a rede da faculdade), então quem busca a imagem é a VPS, não o celular do usuário.
 * Sem auth de propósito: o componente <Image> do React Native não manda o Bearer token.
 */
export async function coverProxyHandler(req: Request, res: Response) {
  const raw = req.query.url;
  if (typeof raw !== 'string') {
    throw new AppError(400, 'validation_error', 'Parâmetro url é obrigatório');
  }

  let target: URL;
  try {
    target = new URL(raw);
  } catch {
    throw new AppError(400, 'validation_error', 'URL inválida');
  }

  if (target.protocol !== 'https:' || target.hostname !== ALLOWED_HOST) {
    throw new AppError(400, 'validation_error', 'Host não permitido');
  }

  const upstream = await fetch(target);
  if (!upstream.ok || !upstream.body) {
    throw new AppError(502, 'image_fetch_failed', 'Falha ao buscar imagem');
  }

  const buffer = Buffer.from(await upstream.arrayBuffer());

  res.setHeader('Content-Type', upstream.headers.get('content-type') ?? 'image/jpeg');
  res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
  res.send(buffer);
}
