export type GameEntryStatus = 'backlog' | 'playing' | 'completed' | 'dropped';

export interface User {
  id: string;
  username: string;
  name: string | null;
  email: string;
  avatarUrl: string | null;
  bannerUrl: string | null;
  bio: string | null;
}

export interface Game {
  id: string;
  igdbId: number;
  name: string;
  summary: string | null;
  coverUrl: string | null;
  screenshots: string[];
  platforms: string[];
  genres: string[];
}

export interface IgdbSearchResult {
  igdbId: number;
  name: string;
  coverUrl: string | null;
  platforms: string[];
  genres: string[];
}

export interface GameEntry {
  id: string;
  userId: string;
  gameId: string;
  platform: string;
  status: GameEntryStatus;
  startedAt: string | null;
  finishedAt: string | null;
  hoursPlayed: string | null;
  rating: number | null;
  notes: string | null;
  createdAt: string;
  game: Game;
}

export interface Session {
  user: User;
  accessToken: string;
  refreshToken: string;
}

export type PostType = 'status' | 'review' | 'activity';

export interface PostAuthor {
  id: string;
  username: string;
  name: string | null;
  avatarUrl: string | null;
}

export interface Post {
  id: string;
  userId: string;
  content: string;
  gameEntryId: string | null;
  type: PostType;
  imageUrl: string | null;
  createdAt: string;
  user: PostAuthor;
  gameEntry: (GameEntry & { game: Game }) | null;
  likeCount: number;
  commentCount: number;
  likedByMe: boolean;
}

export interface Comment {
  id: string;
  postId: string;
  userId: string;
  parentCommentId: string | null;
  content: string;
  createdAt: string;
  user: PostAuthor;
  likeCount: number;
  likedByMe: boolean;
  replies: Comment[];
}

export interface UserReply {
  id: string;
  postId: string;
  userId: string;
  content: string;
  createdAt: string;
  post: { id: string; content: string; user: PostAuthor };
}

export interface PublicProfile {
  id: string;
  username: string;
  name: string | null;
  avatarUrl: string | null;
  bannerUrl: string | null;
  bio: string | null;
  createdAt: string;
  followerCount: number;
  followingCount: number;
  gameEntryCount: number;
  isFollowedByMe: boolean;
}

export type NotificationType = 'like' | 'comment' | 'follow';

export interface AppNotification {
  id: string;
  userId: string;
  actorId: string;
  type: NotificationType;
  postId: string | null;
  read: boolean;
  createdAt: string;
  actor: PostAuthor;
}

export interface Message {
  id: string;
  conversationId: string;
  senderId: string;
  content: string;
  createdAt: string;
  sender: PostAuthor;
}

export interface ConversationSummary {
  id: string;
  otherUser: PostAuthor | null;
  lastMessage: { id: string; content: string; createdAt: string; senderId: string } | null;
  unread: boolean;
}

export interface UserSearchResult {
  id: string;
  username: string;
  name: string | null;
  avatarUrl: string | null;
  bio: string | null;
  isFollowedByMe: boolean;
}

export type FeedScope = 'following' | 'general';
