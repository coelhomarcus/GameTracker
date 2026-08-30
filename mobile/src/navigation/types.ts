import type { GameEntryStatus } from '../types/models';

export type AuthStackParamList = {
  Login: undefined;
  Register: undefined;
};

export type MainTabParamList = {
  Feed: undefined;
  Search: undefined;
  MyGames: undefined;
  Chat: undefined;
  Profile: undefined;
};

export interface TrackingFormInitial {
  platform: string;
  status: GameEntryStatus;
  startedAt: string | null;
  finishedAt: string | null;
  hoursPlayed: string | null;
  rating: number | null;
  notes: string | null;
}

export type RootStackParamList = {
  MainTabs: undefined;
  GameFocus: { igdbId: number };
  TrackingForm: {
    igdbId: number;
    gameName: string;
    platforms: string[];
    entryId?: string;
    initial?: TrackingFormInitial;
  };
  CreatePost: { gameEntryId?: string; prefillContent?: string } | undefined;
  UserProfile: { userId: string };
  Notifications: undefined;
  PostDetail: { postId: string };
  ChatRoom: { conversationId: string; otherUsername: string; otherUserId: string; otherAvatarUrl: string | null };
  FindUsers: undefined;
};
