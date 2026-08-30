import * as Notifications from 'expo-notifications';
import { useEffect } from 'react';
import * as usersApi from '../api/users';

/** Registra o push token da Expo no backend. Falha silenciosamente em emuladores/sem permissão. */
export function usePushRegistration(enabled: boolean) {
  useEffect(() => {
    if (!enabled) return;

    (async () => {
      try {
        const { status: existingStatus } = await Notifications.getPermissionsAsync();
        let finalStatus = existingStatus;
        if (existingStatus !== 'granted') {
          const { status } = await Notifications.requestPermissionsAsync();
          finalStatus = status;
        }
        if (finalStatus !== 'granted') return;

        const { data: token } = await Notifications.getExpoPushTokenAsync();
        await usersApi.setPushToken(token);
      } catch {
        // dispositivo sem suporte a push (emulador, etc.) — segue sem push
      }
    })();
  }, [enabled]);
}
