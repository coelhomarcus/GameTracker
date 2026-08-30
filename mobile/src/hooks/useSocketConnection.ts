import { useEffect } from 'react';
import { getSocket } from '../lib/socket';

export function useSocketConnection(enabled: boolean) {
  useEffect(() => {
    const socket = getSocket();
    if (enabled) {
      socket.connect();
    }
    return () => {
      socket.disconnect();
    };
  }, [enabled]);
}
