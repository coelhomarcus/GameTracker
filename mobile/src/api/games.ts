import type { Game, IgdbSearchResult } from '../types/models';
import { api } from './client';

export function searchGames(q: string) {
  return api.get<IgdbSearchResult[]>('/games/search', { params: { q } }).then((r) => r.data);
}

export function getGame(id: string) {
  return api.get<Game>(`/games/${id}`).then((r) => r.data);
}
