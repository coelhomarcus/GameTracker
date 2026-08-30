import axios, { AxiosError, type InternalAxiosRequestConfig } from 'axios';
import { secureStore } from '../lib/secureStore';
import { useAuthStore } from '../store/authStore';

export const API_URL = process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:3000/api';

export const api = axios.create({ baseURL: API_URL });

// Instância separada, sem interceptors, usada só pra chamar /auth/refresh
// (evita recursão infinita se essa própria chamada retornar 401).
const rawClient = axios.create({ baseURL: API_URL });

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().accessToken;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

let refreshPromise: Promise<string> | null = null;

async function refreshAccessToken(): Promise<string> {
  const currentRefreshToken = useAuthStore.getState().refreshToken;
  if (!currentRefreshToken) {
    throw new Error('Sem refresh token disponível');
  }

  const { data } = await rawClient.post<{ accessToken: string; refreshToken: string }>('/auth/refresh', {
    refreshToken: currentRefreshToken,
  });

  useAuthStore.getState().setAccessToken(data.accessToken);
  useAuthStore.setState({ refreshToken: data.refreshToken });
  await secureStore.setRefreshToken(data.refreshToken);

  return data.accessToken;
}

api.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as (InternalAxiosRequestConfig & { _retry?: boolean }) | undefined;
    const isAuthEndpoint = originalRequest?.url?.startsWith('/auth/');

    if (error.response?.status !== 401 || !originalRequest || originalRequest._retry || isAuthEndpoint) {
      throw error;
    }

    originalRequest._retry = true;

    try {
      refreshPromise ??= refreshAccessToken().finally(() => {
        refreshPromise = null;
      });
      const newAccessToken = await refreshPromise;
      originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
      return api(originalRequest);
    } catch (refreshError) {
      useAuthStore.getState().clearSession();
      await secureStore.clearRefreshToken();
      throw refreshError;
    }
  },
);
