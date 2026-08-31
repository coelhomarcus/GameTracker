import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import multer from 'multer';
import sharp from 'sharp';

const AVATARS_DIR = path.join(process.cwd(), 'uploads', 'avatars');
const BANNERS_DIR = path.join(process.cwd(), 'uploads', 'banners');
fs.mkdirSync(AVATARS_DIR, { recursive: true });
fs.mkdirSync(BANNERS_DIR, { recursive: true });

const imageUploadOptions = {
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (_req: unknown, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
    if (!file.mimetype.startsWith('image/')) {
      cb(new Error('Arquivo precisa ser uma imagem'));
      return;
    }
    cb(null, true);
  },
};

export const avatarUpload = multer(imageUploadOptions);
export const bannerUpload = multer(imageUploadOptions);

/** Redimensiona/comprime e salva o avatar; devolve o path relativo (ex: /uploads/avatars/xxx.jpg). */
export async function saveAvatar(buffer: Buffer): Promise<string> {
  const filename = `${crypto.randomUUID()}.jpg`;
  const filepath = path.join(AVATARS_DIR, filename);

  await sharp(buffer).resize(400, 400, { fit: 'cover' }).jpeg({ quality: 85 }).toFile(filepath);

  return `/uploads/avatars/${filename}`;
}

/** Redimensiona/comprime e salva o banner (3:1, como o do X); devolve o path relativo. */
export async function saveBanner(buffer: Buffer): Promise<string> {
  const filename = `${crypto.randomUUID()}.jpg`;
  const filepath = path.join(BANNERS_DIR, filename);

  await sharp(buffer).resize(1500, 500, { fit: 'cover' }).jpeg({ quality: 85 }).toFile(filepath);

  return `/uploads/banners/${filename}`;
}

async function deleteIfLocal(url: string | null, dir: string, marker: string) {
  if (!url) return;
  const index = url.indexOf(marker);
  if (index === -1) return;

  const filename = url.slice(index + marker.length);
  try {
    await fs.promises.unlink(path.join(dir, filename));
  } catch {
    // arquivo pode já não existir — não é crítico
  }
}

/** Best-effort: apaga um avatar antigo quando o usuário troca de foto. */
export function deleteAvatarIfLocal(avatarUrl: string | null) {
  return deleteIfLocal(avatarUrl, AVATARS_DIR, '/uploads/avatars/');
}

/** Best-effort: apaga um banner antigo quando o usuário troca de capa. */
export function deleteBannerIfLocal(bannerUrl: string | null) {
  return deleteIfLocal(bannerUrl, BANNERS_DIR, '/uploads/banners/');
}
