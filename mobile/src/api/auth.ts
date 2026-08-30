import type { Session, User } from '../types/models';
import { api } from './client';

export function register(input: { username: string; email: string; password: string }) {
  return api.post<Session>('/auth/register', input).then((r) => r.data);
}

export function login(input: { email: string; password: string }) {
  return api.post<Session>('/auth/login', input).then((r) => r.data);
}

export function refresh(refreshToken: string) {
  return api
    .post<{ accessToken: string; refreshToken: string }>('/auth/refresh', { refreshToken })
    .then((r) => r.data);
}

export function logout(refreshToken: string) {
  return api.post('/auth/logout', { refreshToken });
}

export function me() {
  return api.get<User>('/auth/me').then((r) => r.data);
}
