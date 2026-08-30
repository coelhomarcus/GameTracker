import { create } from 'zustand';
import type { Session, User } from '../types/models';

interface AuthState {
  user: User | null;
  accessToken: string | null;
  refreshToken: string | null;
  isHydrating: boolean;
  setSession: (session: Session) => void;
  setAccessToken: (accessToken: string) => void;
  updateUser: (patch: Partial<User>) => void;
  clearSession: () => void;
  setHydrating: (value: boolean) => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  accessToken: null,
  refreshToken: null,
  isHydrating: true,
  setSession: ({ user, accessToken, refreshToken }) => set({ user, accessToken, refreshToken }),
  setAccessToken: (accessToken) => set({ accessToken }),
  updateUser: (patch) => set((state) => ({ user: state.user ? { ...state.user, ...patch } : state.user })),
  clearSession: () => set({ user: null, accessToken: null, refreshToken: null }),
  setHydrating: (isHydrating) => set({ isHydrating }),
}));
