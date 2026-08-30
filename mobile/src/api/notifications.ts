import type { AppNotification } from '../types/models';
import { api } from './client';

export interface NotificationsResponse {
  items: AppNotification[];
  unreadCount: number;
}

export function listNotifications() {
  return api.get<NotificationsResponse>('/notifications').then((r) => r.data);
}

export function markAllRead() {
  return api.post('/notifications/read-all');
}
