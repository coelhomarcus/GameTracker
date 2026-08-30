import type { ConversationSummary, Message } from '../types/models';
import { api } from './client';

export interface MessagesPage {
  items: Message[];
  nextCursor: string | null;
}

export function listConversations() {
  return api.get<ConversationSummary[]>('/conversations').then((r) => r.data);
}

export function createOrGetConversation(userId: string) {
  return api.post<{ id: string }>('/conversations', { userId }).then((r) => r.data);
}

export function getMessages(conversationId: string, cursor?: string) {
  return api
    .get<MessagesPage>(`/conversations/${conversationId}/messages`, { params: cursor ? { cursor } : undefined })
    .then((r) => r.data);
}

export function markConversationRead(conversationId: string) {
  return api.post(`/conversations/${conversationId}/read`);
}
