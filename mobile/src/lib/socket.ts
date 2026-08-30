import { io, type Socket } from 'socket.io-client';
import { API_URL } from '../api/client';
import { useAuthStore } from '../store/authStore';

let socket: Socket | null = null;

function socketUrl() {
  return API_URL.replace(/\/api\/?$/, '');
}

/** Instância única do socket. O token é resolvido a cada (re)conexão, então pega o access token atual. */
export function getSocket(): Socket {
  if (!socket) {
    socket = io(socketUrl(), {
      autoConnect: false,
      auth: (cb) => cb({ token: useAuthStore.getState().accessToken }),
    });
  }
  return socket;
}
