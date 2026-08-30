import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import multer from 'multer';
import sharp from 'sharp';

const UPLOADS_DIR = path.join(process.cwd(), 'uploads', 'avatars');
fs.mkdirSync(UPLOADS_DIR, { recursive: true });

export const avatarUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
      cb(new Error('Arquivo precisa ser uma imagem'));
      return;
    }
    cb(null, true);
  },
});

/** Redimensiona/comprime e salva o avatar; devolve o path relativo (ex: /uploads/avatars/xxx.jpg). */
export async function saveAvatar(buffer: Buffer): Promise<string> {
  const filename = `${crypto.randomUUID()}.jpg`;
  const filepath = path.join(UPLOADS_DIR, filename);

  await sharp(buffer).resize(400, 400, { fit: 'cover' }).jpeg({ quality: 85 }).toFile(filepath);

  return `/uploads/avatars/${filename}`;
}

/** Best-effort: apaga um avatar antigo quando o usuário troca de foto. */
export async function deleteAvatarIfLocal(avatarUrl: string | null) {
  if (!avatarUrl) return;
  const marker = '/uploads/avatars/';
  const index = avatarUrl.indexOf(marker);
  if (index === -1) return;

  const filename = avatarUrl.slice(index + marker.length);
  try {
    await fs.promises.unlink(path.join(UPLOADS_DIR, filename));
  } catch {
    // arquivo pode já não existir — não é crítico
  }
}
