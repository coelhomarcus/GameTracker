/**
 * Cursor opaco pra paginação keyset: codifica (createdAt, id) num token único.
 * Evita um round-trip extra pra recuperar o createdAt do cursor e não quebra se a
 * linha referenciada pelo cursor for deletada entre páginas (diferente do cursor do Prisma).
 */
export function encodeCursor(createdAt: Date, id: string): string {
  return Buffer.from(`${createdAt.toISOString()}_${id}`).toString('base64url');
}

export function decodeCursor(cursor: string): { createdAt: Date; id: string } {
  const decoded = Buffer.from(cursor, 'base64url').toString('utf-8');
  const separatorIndex = decoded.lastIndexOf('_');
  const createdAt = new Date(decoded.slice(0, separatorIndex));
  const id = decoded.slice(separatorIndex + 1);
  return { createdAt, id };
}
