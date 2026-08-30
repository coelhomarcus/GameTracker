import { isAxiosError } from 'axios';

export function getApiErrorMessage(error: unknown, fallback = 'Algo deu errado'): string {
  if (isAxiosError(error)) {
    const message = error.response?.data?.error?.message;
    if (typeof message === 'string') return message;
  }
  return fallback;
}
