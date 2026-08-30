import { AppError } from '../lib/errors';
import { prisma } from '../lib/prisma';
import { findOrCacheGameByIgdbId } from './games.service';

interface CreateInput {
  igdbId: number;
  platform: string;
  status: 'backlog' | 'playing' | 'completed' | 'dropped';
  startedAt?: Date;
  finishedAt?: Date;
  hoursPlayed?: number;
  rating?: number;
  notes?: string;
}

type UpdateInput = Partial<Omit<CreateInput, 'igdbId'>>;

async function getOwnedEntry(userId: string, entryId: string) {
  const entry = await prisma.gameEntry.findUnique({ where: { id: entryId } });
  if (!entry || entry.userId !== userId) {
    throw new AppError(404, 'not_found', 'Registro não encontrado');
  }
  return entry;
}

export async function create(userId: string, input: CreateInput) {
  const game = await findOrCacheGameByIgdbId(input.igdbId);

  return prisma.gameEntry.create({
    data: {
      userId,
      gameId: game.id,
      platform: input.platform,
      status: input.status,
      startedAt: input.startedAt,
      finishedAt: input.finishedAt,
      hoursPlayed: input.hoursPlayed,
      rating: input.rating,
      notes: input.notes,
    },
    include: { game: true },
  });
}

export async function listMine(userId: string, status?: CreateInput['status']) {
  return prisma.gameEntry.findMany({
    where: { userId, ...(status ? { status } : {}) },
    include: { game: true },
    orderBy: { createdAt: 'desc' },
  });
}

export async function update(userId: string, entryId: string, input: UpdateInput) {
  await getOwnedEntry(userId, entryId);
  return prisma.gameEntry.update({
    where: { id: entryId },
    data: input,
    include: { game: true },
  });
}

export async function remove(userId: string, entryId: string) {
  await getOwnedEntry(userId, entryId);
  await prisma.gameEntry.delete({ where: { id: entryId } });
}
