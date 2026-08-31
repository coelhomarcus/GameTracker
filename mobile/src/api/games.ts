import type { Game, GamePlayerEntry, GameStats, IgdbSearchResult, GameEntryStatus, Post } from '../types/models';
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

export function getGameStats(gameId: string) {
  return api.get<GameStats>(`/games/${gameId}/stats`).then((r) => r.data);
}

export function getGamePlayers(
  gameId: string,
  params: { status?: GameEntryStatus; scope?: 'all' | 'following'; limit?: number } = {},
) {
  return api.get<GamePlayerEntry[]>(`/games/${gameId}/players`, { params }).then((r) => r.data);
}

export interface GamePostsPage {
  items: Post[];
  nextCursor: string | null;
}

export function getGamePosts(gameId: string, cursor?: string) {
  return api
    .get<GamePostsPage>(`/games/${gameId}/posts`, { params: cursor ? { cursor } : undefined })
    .then((r) => r.data);
}
