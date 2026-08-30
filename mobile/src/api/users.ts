import type { Post, PublicProfile, UserSearchResult } from '../types/models';
import { api } from './client';

export function getPublicProfile(userId: string) {
  return api.get<PublicProfile>(`/users/${userId}`).then((r) => r.data);
}

export function searchUsers(q: string) {
  return api.get<UserSearchResult[]>('/users/search', { params: { q } }).then((r) => r.data);
}

export function follow(userId: string) {
  return api.post(`/users/${userId}/follow`);
}

export function unfollow(userId: string) {
  return api.delete(`/users/${userId}/follow`);
}

export function setPushToken(token: string) {
  return api.post('/users/me/push-token', { token });
}

export function updateProfile(input: { bio?: string }) {
  return api.patch('/users/me', input);
}

export function uploadAvatar(uri: string) {
  const formData = new FormData();
  // @ts-expect-error -- React Native's FormData aceita esse shape de arquivo, diferente do DOM
  formData.append('avatar', { uri, name: 'avatar.jpg', type: 'image/jpeg' });

  return api
    .post<{ avatarUrl: string }>('/users/me/avatar', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    .then((r) => r.data);
}

export interface UserPostsPage {
  items: Post[];
  nextCursor: string | null;
}

export function getUserPosts(userId: string, cursor?: string) {
  return api
    .get<UserPostsPage>(`/users/${userId}/posts`, { params: cursor ? { cursor } : undefined })
    .then((r) => r.data);
}
