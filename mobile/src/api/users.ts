import type { PublicProfile } from '../types/models';
import { api } from './client';

export function getPublicProfile(userId: string) {
  return api.get<PublicProfile>(`/users/${userId}`).then((r) => r.data);
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
