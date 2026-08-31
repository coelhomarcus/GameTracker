import type { Comment, FeedScope, Post, PostType } from '../types/models';
import { api } from './client';

export interface CreatePostInput {
  content: string;
  gameEntryId?: string;
  type?: PostType;
  imageUrl?: string;
}

export interface FeedPage {
  items: Post[];
  nextCursor: string | null;
}

export function createPost(input: CreatePostInput) {
  return api.post<Post>('/posts', input).then((r) => r.data);
}

export function getPost(postId: string) {
  return api.get<Post>(`/posts/${postId}`).then((r) => r.data);
}

export function getFeed(scope: FeedScope, cursor?: string) {
  return api.get<FeedPage>('/feed', { params: { scope, ...(cursor ? { cursor } : {}) } }).then((r) => r.data);
}

export function likePost(postId: string) {
  return api.post(`/posts/${postId}/like`);
}

export function unlikePost(postId: string) {
  return api.delete(`/posts/${postId}/like`);
}

export function addComment(postId: string, content: string, parentCommentId?: string) {
  return api.post<Comment>(`/posts/${postId}/comments`, { content, parentCommentId }).then((r) => r.data);
}

export function listComments(postId: string) {
  return api.get<Comment[]>(`/posts/${postId}/comments`).then((r) => r.data);
}

export function likeComment(commentId: string) {
  return api.post(`/comments/${commentId}/like`);
}

export function unlikeComment(commentId: string) {
  return api.delete(`/comments/${commentId}/like`);
}
