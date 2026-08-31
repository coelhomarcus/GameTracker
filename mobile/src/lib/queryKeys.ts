import type { FeedScope, GameEntryStatus } from '../types/models';

/**
 * Um lugar só nomeando as chaves. Os quatro handlers de like invalidavam
 * subconjuntos diferentes justamente porque esse lugar não existia.
 */
export const qk = {
  feed: () => ['feed'] as const,
  feedScope: (scope: FeedScope) => ['feed', scope] as const,

  post: (postId: string) => ['post', postId] as const,
  postComments: (postId: string) => ['post-comments', postId] as const,

  userProfile: (userId?: string) => ['user-profile', userId] as const,
  userPosts: (userId?: string, type?: 'activity' | 'post') => ['user-posts', userId, type] as const,
  userReplies: (userId?: string) => ['user-replies', userId] as const,
  userGameEntries: (userId?: string, status?: GameEntryStatus | 'all') =>
    ['user-game-entries', userId, status] as const,

  gameEntries: () => ['game-entries'] as const,
  gameEntriesFiltered: (status: GameEntryStatus | 'all') => ['game-entries', status] as const,
  gameEntriesByIgdb: (igdbId: number) => ['game-entries', 'igdb', igdbId] as const,
  gameFocus: (igdbId: number) => ['game-focus', igdbId] as const,

  gameStats: (gameId: string) => ['game-stats', gameId] as const,
  gamePlayers: (gameId: string, status: GameEntryStatus, scope: 'all' | 'following') =>
    ['game-players', gameId, status, scope] as const,
  gamePosts: (gameId: string) => ['game-posts', gameId] as const,

  notifications: () => ['notifications'] as const,
  conversations: () => ['conversations'] as const,
  usersSearch: (term?: string) => (term === undefined ? (['users', 'search'] as const) : (['users', 'search', term] as const)),
  gamesSearch: (term: string) => ['games', 'search', term] as const,
};

/** Tudo que exibe um post e precisa refletir um like. */
export const POST_CONTAINER_KEYS = [qk.feed(), ['user-posts']] as const;
