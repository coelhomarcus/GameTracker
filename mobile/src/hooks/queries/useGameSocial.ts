import { useQuery } from '@tanstack/react-query';
import * as gamesApi from '../../api/games';
import { qk } from '../../lib/queryKeys';
import type { GameEntryStatus } from '../../types/models';
import { useInfiniteList } from './useInfiniteList';

export function useGameStats(gameId: string, enabled = true) {
  return useQuery({
    queryKey: qk.gameStats(gameId),
    queryFn: () => gamesApi.getGameStats(gameId),
    enabled: enabled && !!gameId,
  });
}

/** Prévia limitada (sem paginação) — "quem está jogando" / "seus amigos estão jogando". */
export function useGamePlayers(gameId: string, status: GameEntryStatus, scope: 'all' | 'following', enabled = true) {
  return useQuery({
    queryKey: qk.gamePlayers(gameId, status, scope),
    queryFn: () => gamesApi.getGamePlayers(gameId, { status, scope }),
    enabled: enabled && !!gameId,
  });
}

export function useGamePosts(gameId: string, enabled = true) {
  return useInfiniteList({
    queryKey: qk.gamePosts(gameId),
    fetchPage: (cursor?: string) => gamesApi.getGamePosts(gameId, cursor),
    enabled: enabled && !!gameId,
  });
}
