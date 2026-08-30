import type { Game, IgdbSearchResult } from '../types/models';
import { api } from './client';

export function searchGames(q: string) {
  return api.get<IgdbSearchResult[]>('/games/search', { params: { q } }).then((r) => r.data);
}

export function getGame(id: string) {
  return api.get<Game>(`/games/${id}`).then((r) => r.data);
}

/** Busca (ou cacheia, se ainda não existir) o jogo pelo id da IGDB. */
export function getGameByIgdb(igdbId: number) {
  return api.get<Game>(`/games/igdb/${igdbId}`).then((r) => r.data);
}
