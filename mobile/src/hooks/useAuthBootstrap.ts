import { useEffect } from 'react';
import * as authApi from '../api/auth';
import { secureStore } from '../lib/secureStore';
import { useAuthStore } from '../store/authStore';

/** Ao abrir o app, tenta restaurar a sessão a partir do refresh token salvo. */
export function useAuthBootstrap() {
  useEffect(() => {
    let cancelled = false;

    async function bootstrap() {
      const savedRefreshToken = await secureStore.getRefreshToken();
      if (!savedRefreshToken) {
        useAuthStore.getState().setHydrating(false);
        return;
      }

      try {
        const tokens = await authApi.refresh(savedRefreshToken);
        useAuthStore.setState({ accessToken: tokens.accessToken, refreshToken: tokens.refreshToken });
        await secureStore.setRefreshToken(tokens.refreshToken);

        const user = await authApi.me();
        if (!cancelled) useAuthStore.setState({ user });
      } catch {
        await secureStore.clearRefreshToken();
        if (!cancelled) useAuthStore.getState().clearSession();
      } finally {
        if (!cancelled) useAuthStore.getState().setHydrating(false);
      }
    }

    bootstrap();
    return () => {
      cancelled = true;
    };
  }, []);
}
