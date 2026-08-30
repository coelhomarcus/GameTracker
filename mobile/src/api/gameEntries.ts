import type { GameEntry, GameEntryStatus } from '../types/models';
import { api } from './client';

export interface CreateGameEntryInput {
  igdbId: number;
  platform: string;
  status: GameEntryStatus;
  startedAt?: string;
  finishedAt?: string;
  hoursPlayed?: number;
  rating?: number;
  notes?: string;
}

export type UpdateGameEntryInput = Partial<Omit<CreateGameEntryInput, 'igdbId'>>;

export function createGameEntry(input: CreateGameEntryInput) {
  return api.post<GameEntry>('/game-entries', input).then((r) => r.data);
}

export function listMyGameEntries(status?: GameEntryStatus) {
  return api.get<GameEntry[]>('/game-entries/me', { params: status ? { status } : undefined }).then((r) => r.data);
}

export function updateGameEntry(id: string, input: UpdateGameEntryInput) {
  return api.patch<GameEntry>(`/game-entries/${id}`, input).then((r) => r.data);
}

export function deleteGameEntry(id: string) {
  return api.delete(`/game-entries/${id}`);
}
