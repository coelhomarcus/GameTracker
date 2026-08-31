import { relations } from 'drizzle-orm';
import {
  boolean,
  date,
  index,
  integer,
  numeric,
  pgEnum,
  pgTable,
  smallint,
  text,
  timestamp,
  unique,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

export const gameEntryStatusEnum = pgEnum('game_entry_status', ['backlog', 'playing', 'completed', 'dropped']);
export const postTypeEnum = pgEnum('post_type', ['status', 'review', 'activity']);
export const notificationTypeEnum = pgEnum('notification_type', ['like', 'comment', 'follow']);

export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  username: varchar('username', { length: 30 }).notNull().unique(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  passwordHash: varchar('password_hash', { length: 255 }).notNull(),
  avatarUrl: varchar('avatar_url', { length: 500 }),
  bannerUrl: varchar('banner_url', { length: 500 }),
  bio: varchar('bio', { length: 280 }),
  expoPushToken: varchar('expo_push_token', { length: 255 }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const refreshTokens = pgTable(
  'refresh_tokens',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    tokenHash: varchar('token_hash', { length: 255 }).notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    revokedAt: timestamp('revoked_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    userIdIdx: index('refresh_tokens_user_id_idx').on(table.userId),
  }),
);

/** Cache local dos jogos vindos da IGDB — populado sob demanda quando um usuário trackeia um jogo. */
export const games = pgTable('games', {
  id: uuid('id').primaryKey().defaultRandom(),
  igdbId: integer('igdb_id').notNull().unique(),
  name: varchar('name', { length: 255 }).notNull(),
  coverUrl: varchar('cover_url', { length: 500 }),
  summary: text('summary'),
  screenshots: text('screenshots').array().notNull().default([]),
  platforms: text('platforms').array().notNull(),
  genres: text('genres').array().notNull(),
  cachedAt: timestamp('cached_at', { withTimezone: true }).notNull().defaultNow(),
});

/** Um registro por playthrough — sem unique(userId, gameId) para permitir replays. */
export const gameEntries = pgTable(
  'game_entries',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    gameId: uuid('game_id')
      .notNull()
      .references(() => games.id, { onDelete: 'restrict' }),
    platform: varchar('platform', { length: 50 }).notNull(),
    status: gameEntryStatusEnum('status').notNull().default('backlog'),
    startedAt: date('started_at', { mode: 'date' }),
    finishedAt: date('finished_at', { mode: 'date' }),
    hoursPlayed: numeric('hours_played', { precision: 6, scale: 1 }),
    rating: smallint('rating'),
    notes: text('notes'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    userIdIdx: index('game_entries_user_id_idx').on(table.userId),
    gameIdIdx: index('game_entries_game_id_idx').on(table.gameId),
  }),
);

export const posts = pgTable(
  'posts',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    content: varchar('content', { length: 500 }).notNull(),
    gameEntryId: uuid('game_entry_id').references(() => gameEntries.id, { onDelete: 'set null' }),
    type: postTypeEnum('type').notNull().default('status'),
    imageUrl: varchar('image_url', { length: 500 }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    userIdIdx: index('posts_user_id_idx').on(table.userId),
    // composto pra keyset pagination (order by created_at desc, id desc)
    createdAtIdx: index('posts_created_at_id_idx').on(table.createdAt, table.id),
  }),
);

export const comments = pgTable(
  'comments',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    postId: uuid('post_id')
      .notNull()
      .references(() => posts.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    content: varchar('content', { length: 500 }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    postIdIdx: index('comments_post_id_idx').on(table.postId),
  }),
);

/** Um like por (post, usuário) — unique constraint evita curtir duas vezes. */
export const likes = pgTable(
  'likes',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    postId: uuid('post_id')
      .notNull()
      .references(() => posts.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    postUserUnique: unique('likes_post_id_user_id_unique').on(table.postId, table.userId),
  }),
);

export const follows = pgTable(
  'follows',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    followerId: uuid('follower_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    followingId: uuid('following_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    followerFollowingUnique: unique('follows_follower_id_following_id_unique').on(table.followerId, table.followingId),
  }),
);

export const notifications = pgTable(
  'notifications',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    actorId: uuid('actor_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    type: notificationTypeEnum('type').notNull(),
    postId: uuid('post_id').references(() => posts.id, { onDelete: 'cascade' }),
    read: boolean('read').notNull().default(false),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    userIdIdx: index('notifications_user_id_idx').on(table.userId),
  }),
);

export const conversations = pgTable('conversations', {
  id: uuid('id').primaryKey().defaultRandom(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const conversationParticipants = pgTable(
  'conversation_participants',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    conversationId: uuid('conversation_id')
      .notNull()
      .references(() => conversations.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    lastReadAt: timestamp('last_read_at', { withTimezone: true }),
    joinedAt: timestamp('joined_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    conversationUserUnique: unique('conversation_participants_conversation_id_user_id_unique').on(
      table.conversationId,
      table.userId,
    ),
    userIdIdx: index('conversation_participants_user_id_idx').on(table.userId),
  }),
);

export const messages = pgTable(
  'messages',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    conversationId: uuid('conversation_id')
      .notNull()
      .references(() => conversations.id, { onDelete: 'cascade' }),
    senderId: uuid('sender_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    content: varchar('content', { length: 2000 }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    // composto pra keyset pagination (order by created_at desc, id desc)
    conversationCreatedIdx: index('messages_conversation_id_created_at_id_idx').on(
      table.conversationId,
      table.createdAt,
      table.id,
    ),
  }),
);

// ---------- relations ----------

export const usersRelations = relations(users, ({ many }) => ({
  refreshTokens: many(refreshTokens),
  gameEntries: many(gameEntries),
  posts: many(posts),
  comments: many(comments),
  likes: many(likes),
  following: many(follows, { relationName: 'follower' }),
  followers: many(follows, { relationName: 'following' }),
  notificationsReceived: many(notifications, { relationName: 'notificationRecipient' }),
  notificationsCaused: many(notifications, { relationName: 'notificationActor' }),
  conversationParticipants: many(conversationParticipants),
  messages: many(messages),
}));

export const refreshTokensRelations = relations(refreshTokens, ({ one }) => ({
  user: one(users, { fields: [refreshTokens.userId], references: [users.id] }),
}));

export const gamesRelations = relations(games, ({ many }) => ({
  gameEntries: many(gameEntries),
}));

export const gameEntriesRelations = relations(gameEntries, ({ one, many }) => ({
  user: one(users, { fields: [gameEntries.userId], references: [users.id] }),
  game: one(games, { fields: [gameEntries.gameId], references: [games.id] }),
  posts: many(posts),
}));

export const postsRelations = relations(posts, ({ one, many }) => ({
  user: one(users, { fields: [posts.userId], references: [users.id] }),
  gameEntry: one(gameEntries, { fields: [posts.gameEntryId], references: [gameEntries.id] }),
  comments: many(comments),
  likes: many(likes),
  notifications: many(notifications),
}));

export const commentsRelations = relations(comments, ({ one }) => ({
  post: one(posts, { fields: [comments.postId], references: [posts.id] }),
  user: one(users, { fields: [comments.userId], references: [users.id] }),
}));

export const likesRelations = relations(likes, ({ one }) => ({
  post: one(posts, { fields: [likes.postId], references: [posts.id] }),
  user: one(users, { fields: [likes.userId], references: [users.id] }),
}));

export const followsRelations = relations(follows, ({ one }) => ({
  follower: one(users, { fields: [follows.followerId], references: [users.id], relationName: 'follower' }),
  following: one(users, { fields: [follows.followingId], references: [users.id], relationName: 'following' }),
}));

export const notificationsRelations = relations(notifications, ({ one }) => ({
  user: one(users, {
    fields: [notifications.userId],
    references: [users.id],
    relationName: 'notificationRecipient',
  }),
  actor: one(users, {
    fields: [notifications.actorId],
    references: [users.id],
    relationName: 'notificationActor',
  }),
  post: one(posts, { fields: [notifications.postId], references: [posts.id] }),
}));

export const conversationsRelations = relations(conversations, ({ many }) => ({
  participants: many(conversationParticipants),
  messages: many(messages),
}));

export const conversationParticipantsRelations = relations(conversationParticipants, ({ one }) => ({
  conversation: one(conversations, {
    fields: [conversationParticipants.conversationId],
    references: [conversations.id],
  }),
  user: one(users, { fields: [conversationParticipants.userId], references: [users.id] }),
}));

export const messagesRelations = relations(messages, ({ one }) => ({
  conversation: one(conversations, { fields: [messages.conversationId], references: [conversations.id] }),
  sender: one(users, { fields: [messages.senderId], references: [users.id] }),
}));
