import { useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import * as usersApi from '../../api/users';
import { qk } from '../../lib/queryKeys';
import { useAuthStore } from '../../store/authStore';
import type { GameEntryStatus, PublicProfile, User } from '../../types/models';
import { useInfiniteList } from './useInfiniteList';

export type ProfileTab = 'backlog' | 'activities' | 'posts' | 'replies';

/**
 * As duas telas de perfil liam identidade de fontes diferentes (a store do
 * zustand no próprio perfil, a query no de terceiros) e por isso divergiam.
 * Aqui a query é a única fonte; no próprio perfil a store só semeia o primeiro
 * render pra não perder a exibição instantânea.
 */
function seedFromAuthUser(user: User | null): PublicProfile | undefined {
  if (!user) return undefined;

  return {
    id: user.id,
    username: user.username,
    name: user.name,
    avatarUrl: user.avatarUrl,
    bannerUrl: user.bannerUrl,
    bio: user.bio,
    createdAt: new Date().toISOString(),
    followerCount: 0,
    followingCount: 0,
    gameEntryCount: 0,
    isFollowedByMe: false,
  };
}

interface Options {
  userId: string;
  isSelf: boolean;
  tab: ProfileTab;
  gameFilter: GameEntryStatus | 'all';
  enabled?: boolean;
}

export function useProfileData({ userId, isSelf, tab, gameFilter, enabled = true }: Options) {
  const authUser = useAuthStore((state) => state.user);
  const seed = useMemo(() => (isSelf ? seedFromAuthUser(authUser) : undefined), [isSelf, authUser]);

  const profile = useQuery({
    queryKey: qk.userProfile(userId),
    queryFn: () => usersApi.getPublicProfile(userId),
    enabled: enabled && !!userId,
    placeholderData: seed,
  });

  const backlog = useQuery({
    queryKey: qk.userGameEntries(userId, gameFilter),
    queryFn: () => usersApi.getUserGameEntries(userId, gameFilter === 'all' ? undefined : gameFilter),
    enabled: enabled && !!userId && tab === 'backlog',
  });

  const activities = useInfiniteList({
    queryKey: qk.userPosts(userId, 'activity'),
    fetchPage: (cursor?: string) => usersApi.getUserPosts(userId, cursor, 'activity'),
    enabled: enabled && !!userId && tab === 'activities',
  });

  const posts = useInfiniteList({
    queryKey: qk.userPosts(userId, 'post'),
    fetchPage: (cursor?: string) => usersApi.getUserPosts(userId, cursor, 'post'),
    enabled: enabled && !!userId && tab === 'posts',
  });

  const replies = useInfiniteList({
    queryKey: qk.userReplies(userId),
    fetchPage: (cursor?: string) => usersApi.getUserReplies(userId, cursor),
    enabled: enabled && !!userId && tab === 'replies',
  });

  return { profile, backlog, activities, posts, replies };
}
