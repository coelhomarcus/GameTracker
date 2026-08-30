import { useAuthStore } from '../store/authStore';
import type { Session } from '../types/models';
import { secureStore } from './secureStore';

export async function applySession(session: Session) {
  useAuthStore.getState().setSession(session);
  await secureStore.setRefreshToken(session.refreshToken);
}

export async function clearSessionEverywhere() {
  useAuthStore.getState().clearSession();
  await secureStore.clearRefreshToken();
}
