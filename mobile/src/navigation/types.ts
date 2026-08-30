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

export type RootStackParamList = {
  MainTabs: undefined;
  GameDetail: {
    igdbId: number;
    name: string;
    coverUrl: string | null;
    platforms: string[];
    genres: string[];
  };
  CreatePost: { gameEntryId?: string; prefillContent?: string } | undefined;
  UserProfile: { userId: string };
  Notifications: undefined;
  PostDetail: { postId: string };
  ChatRoom: { conversationId: string; otherUsername: string };
};
