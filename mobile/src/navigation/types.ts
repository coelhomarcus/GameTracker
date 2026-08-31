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
  // Não renderiza tela própria: o tabPress é interceptado e navega pra
  // rota "Profile" da RootStack (nome diferente pra não colidir com ela).
  ProfileTab: undefined;
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
  CreatePost:
    | {
        // Playthrough específico (ex: "zerei, quero postar") — precisa de
        // gameName/gameCoverUrl junto pra mostrar o chip sem round-trip extra.
        gameEntryId?: string;
        // Jogo qualquer, sem playthrough associado (ex: "postar sobre este jogo").
        gameId?: string;
        gameName?: string;
        gameCoverUrl?: string | null;
        prefillContent?: string;
      }
    | undefined;
  UserProfile: { userId: string };
  Profile: undefined;
  EditProfile: undefined;
  Settings: undefined;
  Notifications: undefined;
  PostDetail: { postId: string };
  ChatRoom: {
    conversationId: string;
    otherUsername: string;
    otherName: string | null;
    otherUserId: string;
    otherAvatarUrl: string | null;
  };
};
